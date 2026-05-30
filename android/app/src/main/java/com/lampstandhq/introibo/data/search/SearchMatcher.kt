package com.lampstandhq.introibo.data.search

import kotlin.math.abs
import kotlin.math.min

// MARK: - SearchMatcher (Phase 2: matcher)
//
// The cross-platform query engine. Like `fold`, this is pure and MUST stay in
// lock-step with the iOS mirror at:
//   Introibo/Data/Search/SearchMatcher.swift
//
// Algorithm (identical on both platforms; guarded by the golden query fixtures
// in search_query_golden.json):
//   1. Fold the query (SearchNormalizer.fold) and split on whitespace into
//      tokens. Empty query -> [].
//   2. A document MATCHES if EVERY query token is found in `doc.searchText`:
//        a. substring hit: doc.searchText contains the token; OR
//        b. fuzzy fallback (only for tokens with no substring hit anywhere):
//           split doc.searchText into whitespace tokens; the query token
//           matches if any doc token is within Levenshtein distance
//           1 (query token <=5 chars) or 2 (longer).
//   3. Score for ORDERING, summed across tokens:
//        titleHit (token in folded title)       +100
//        exact whole-token match (== doc token)  +10
//        substring                               +1
//        fuzzy                                    0
//      Higher score first; ties broken by stable document order.
//   4. Build a ~12-word snippet of `doc.displayText` centred on the first match.

/** A snippet of display text (WITH diacritics) plus the ranges to highlight. */
data class SearchSnippet(
    val text: String,
    /** Inclusive-start / exclusive-end character offsets into [text]. */
    val highlightRanges: List<IntRange>,
)

/** One scored search hit. */
data class SearchResult(
    val document: SearchDocument,
    val score: Int,
    val snippet: SearchSnippet,
)

object SearchMatcher {

    /**
     * Pure query -> ranked results. [typeFilter] (if non-null) restricts to one
     * content type before matching.
     */
    fun search(
        query: String,
        index: SearchIndex,
        typeFilter: ContentType? = null,
    ): List<SearchResult> {
        val folded = SearchNormalizer.fold(query)
        val tokens = folded.split(" ").filter { it.isNotEmpty() }
        if (tokens.isEmpty()) return emptyList()

        val matched = mutableListOf<Pair<SearchResult, Int>>()
        index.documents.forEachIndexed { order, doc ->
            if (typeFilter != null && doc.type != typeFilter) return@forEachIndexed
            val score = scoreDocument(doc, tokens) ?: return@forEachIndexed
            val snippet = makeSnippet(doc, tokens)
            matched.add(SearchResult(doc, score, snippet) to order)
        }

        // Higher score first; ties broken by stable original document order.
        matched.sortWith(
            compareByDescending<Pair<SearchResult, Int>> { it.first.score }
                .thenBy { it.second }
        )
        return matched.map { it.first }
    }

    // ---- Scoring ----

    /** Returns the ordering score if EVERY token matches, else null. */
    private fun scoreDocument(doc: SearchDocument, tokens: List<String>): Int? {
        val searchText = doc.searchText
        val foldedTitle = SearchNormalizer.fold(doc.title)
        val docTokens = searchText.split(" ").filter { it.isNotEmpty() }

        var total = 0
        for (token in tokens) {
            var tokenScore: Int? = null

            if (searchText.contains(token)) {
                // Substring hit. Promote to exact if it equals a whole doc token.
                tokenScore = if (docTokens.contains(token)) 10 else 1
            } else {
                // Fuzzy fallback — only when there is no substring hit.
                val maxDistance = if (token.length <= 5) 1 else 2
                if (docTokens.any { Levenshtein.isWithin(it, token, maxDistance) }) {
                    tokenScore = 0
                }
            }

            val base = tokenScore ?: return null // token unmatched → doc fails
            var add = base
            if (foldedTitle.contains(token)) add += 100 // title bonus
            total += add
        }
        return total
    }

    // ---- Snippet ----

    /**
     * A ~12-word window of [SearchDocument.displayText] centred on the first
     * matched token, with diacritic- & case-insensitive highlight ranges. A
     * missed highlight is acceptable; ranges are always valid offsets into the
     * returned snippet text.
     */
    private fun makeSnippet(doc: SearchDocument, tokens: List<String>): SearchSnippet {
        val display = doc.displayText
        if (display.isEmpty()) {
            return SearchSnippet(doc.title, emptyList())
        }

        // Find the first display-space match (diacritic- & case-insensitive).
        var anchorIndex = -1
        for (token in tokens) {
            val idx = indexOfFolded(display, token, 0)
            if (idx >= 0) {
                anchorIndex = idx
                break
            }
        }

        val words = display.split(" ").filter { it.isNotEmpty() }
        val windowSize = 12

        val snippetText: String
        if (anchorIndex >= 0 && words.isNotEmpty()) {
            val prefix = display.substring(0, anchorIndex)
            val wordsBefore = prefix.split(" ").filter { it.isNotEmpty() }.size
            val half = windowSize / 2
            val start = maxOf(0, wordsBefore - half)
            val end = min(words.size, start + windowSize)
            val realStart = maxOf(0, end - windowSize)
            var window = words.subList(realStart, end).joinToString(" ")
            if (realStart > 0) window = "…$window"
            if (end < words.size) window += "…"
            snippetText = window
        } else {
            val end = min(words.size, windowSize)
            var window = words.subList(0, end).joinToString(" ")
            if (end < words.size) window += "…"
            snippetText = window
        }

        // Compute highlight ranges within the snippet for every token.
        val highlights = mutableListOf<IntRange>()
        for (token in tokens) {
            if (token.isEmpty()) continue
            var from = 0
            while (from <= snippetText.length) {
                val idx = indexOfFolded(snippetText, token, from)
                if (idx < 0) break
                val matchLen = foldedMatchLength(snippetText, token, idx)
                if (matchLen <= 0) { from = idx + 1; continue }
                highlights.add(idx until (idx + matchLen))
                from = idx + matchLen
            }
        }
        return SearchSnippet(snippetText, highlights)
    }

    // ---- Diacritic- & case-insensitive search (mirror of iOS
    //      String.range(of:options:[.caseInsensitive,.diacriticInsensitive])) ----

    /**
     * Returns the index in [haystack] (>= [start]) where [foldedToken] (already
     * folded) first matches, comparing folded character-by-character, or -1.
     * Folding here reuses SearchNormalizer.fold so it matches the index exactly.
     */
    private fun indexOfFolded(haystack: String, foldedToken: String, start: Int): Int {
        if (foldedToken.isEmpty()) return -1
        var i = start
        while (i < haystack.length) {
            if (foldedMatchLength(haystack, foldedToken, i) > 0) return i
            i++
        }
        return -1
    }

    /**
     * If [haystack] starting at [at] folds to a string that begins with
     * [foldedToken], returns the number of raw characters consumed; else 0.
     * Computed by folding successively longer raw substrings until the folded
     * length reaches the token length.
     */
    private fun foldedMatchLength(haystack: String, foldedToken: String, at: Int): Int {
        var len = 1
        while (at + len <= haystack.length) {
            val foldedSlice = SearchNormalizer.fold(haystack.substring(at, at + len))
            if (foldedSlice.length >= foldedToken.length) {
                return if (foldedSlice.startsWith(foldedToken)) len else 0
            }
            // Folding can collapse a char to empty (e.g. punctuation); keep growing.
            len++
        }
        return 0
    }
}

// MARK: - Levenshtein

/**
 * Pure edit-distance helper, mirrored on iOS. Two rolling rows; no
 * dependencies. [isWithin] short-circuits as soon as the best achievable
 * distance on a row exceeds [maxDistance].
 */
object Levenshtein {

    /** Full Levenshtein distance between two strings (character-wise). */
    fun distance(a: String, b: String): Int {
        if (a.isEmpty()) return b.length
        if (b.isEmpty()) return a.length

        var previous = IntArray(b.length + 1) { it }
        var current = IntArray(b.length + 1)
        for (i in 1..a.length) {
            current[0] = i
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                current[j] = minOf(
                    previous[j] + 1,       // deletion
                    current[j - 1] + 1,    // insertion
                    previous[j - 1] + cost // substitution
                )
            }
            val tmp = previous; previous = current; current = tmp
        }
        return previous[b.length]
    }

    /** True if the edit distance between [a] and [b] is <= [maxDistance]. */
    fun isWithin(a: String, b: String, maxDistance: Int): Boolean {
        if (abs(a.length - b.length) > maxDistance) return false
        if (a.isEmpty()) return b.length <= maxDistance
        if (b.isEmpty()) return a.length <= maxDistance

        var previous = IntArray(b.length + 1) { it }
        var current = IntArray(b.length + 1)
        for (i in 1..a.length) {
            current[0] = i
            var rowMin = current[0]
            for (j in 1..b.length) {
                val cost = if (a[i - 1] == b[j - 1]) 0 else 1
                current[j] = minOf(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
                rowMin = min(rowMin, current[j])
            }
            if (rowMin > maxDistance) return false // no path can recover
            val tmp = previous; previous = current; current = tmp
        }
        return previous[b.length] <= maxDistance
    }
}
