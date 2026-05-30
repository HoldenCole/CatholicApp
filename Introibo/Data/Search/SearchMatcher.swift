import Foundation

// MARK: - SearchMatcher (Phase 2: matcher)
//
// The cross-platform query engine. Like `fold`, this is pure and MUST stay in
// lock-step with the Android mirror at:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchMatcher.kt
//
// Algorithm (identical on both platforms; guarded by the golden query fixtures
// in search_query_golden.json):
//   1. Fold the query (SearchNormalizer.fold) and split on whitespace into
//      tokens. Empty query → [].
//   2. A document MATCHES if EVERY query token is found in `doc.searchText`:
//        a. substring hit: doc.searchText contains the token (partial match,
//           e.g. "magn" matches "magnificat"); OR
//        b. fuzzy fallback (only for tokens with no substring hit anywhere):
//           split doc.searchText into whitespace tokens; the query token
//           matches if any doc token is within Levenshtein distance
//           1 (query token ≤5 chars) or 2 (longer).
//   3. Score for ORDERING (not ranking sophistication), summed across tokens:
//        titleHit (token in folded title)      +100
//        exact whole-token match (== doc token) +10
//        substring                              +1
//        fuzzy                                   0
//      Higher score first; ties broken by stable document order.
//   4. Build a ~12-word snippet of `doc.displayText` centred on the first match.

// MARK: - Result types

/// A snippet of display text (WITH diacritics) plus the ranges to highlight.
struct SearchSnippet {
    let text: String
    let highlightRanges: [Range<String.Index>]
}

/// One scored search hit.
struct SearchResult: Identifiable {
    let document: SearchDocument
    let score: Int
    let snippet: SearchSnippet

    var id: String { document.id }
}

enum SearchMatcher {

    /// Pure query → ranked results. `typeFilter` (if non-nil) restricts to one
    /// content type before matching.
    static func search(
        _ query: String,
        in index: SearchIndex,
        typeFilter: ContentType? = nil
    ) -> [SearchResult] {
        let folded = SearchNormalizer.fold(query)
        let tokens = folded.split(separator: " ").map(String.init)
        if tokens.isEmpty { return [] }

        var results: [(result: SearchResult, order: Int)] = []
        var order = 0
        for doc in index.documents {
            defer { order += 1 }
            if let typeFilter, doc.type != typeFilter { continue }
            guard let score = scoreDocument(doc, tokens: tokens) else { continue }
            let snippet = makeSnippet(for: doc, tokens: tokens)
            results.append((SearchResult(document: doc, score: score, snippet: snippet), order))
        }

        // Higher score first; ties broken by stable original document order.
        results.sort { lhs, rhs in
            if lhs.result.score != rhs.result.score {
                return lhs.result.score > rhs.result.score
            }
            return lhs.order < rhs.order
        }
        return results.map { $0.result }
    }

    // MARK: - Scoring

    /// Returns the ordering score if EVERY token matches, else nil.
    private static func scoreDocument(_ doc: SearchDocument, tokens: [String]) -> Int? {
        let searchText = doc.searchText
        let foldedTitle = SearchNormalizer.fold(doc.title)
        // Split once; reused for exact / fuzzy checks.
        let docTokens = searchText.split(separator: " ").map(String.init)

        var total = 0
        for token in tokens {
            var tokenScore: Int?

            if searchText.contains(token) {
                // Substring hit. Promote to exact if it equals a whole doc token.
                tokenScore = docTokens.contains(token) ? 10 : 1
            } else {
                // Fuzzy fallback — only runs when there is no substring hit.
                let maxDistance = token.count <= 5 ? 1 : 2
                if docTokens.contains(where: {
                    Levenshtein.isWithin($0, token, maxDistance: maxDistance)
                }) {
                    tokenScore = 0
                }
            }

            guard let base = tokenScore else { return nil } // token unmatched → doc fails
            var add = base
            if foldedTitle.contains(token) { add += 100 } // title bonus
            total += add
        }
        return total
    }

    // MARK: - Snippet

    /// A ~12-word window of `displayText` centred on the first matched token,
    /// with diacritic-insensitive highlight ranges. A missed highlight is fine;
    /// a crash is not — every range operation is bounds-checked by construction
    /// (ranges come from `range(of:)`, always valid for the same string).
    private static func makeSnippet(for doc: SearchDocument, tokens: [String]) -> SearchSnippet {
        let display = doc.displayText
        guard !display.isEmpty else {
            return SearchSnippet(text: doc.title, highlightRanges: [])
        }

        // Find the first display-space match for any query token (diacritic- &
        // case-insensitive). This anchors the window.
        var anchorRange: Range<String.Index>?
        for token in tokens {
            if let r = display.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) {
                anchorRange = r
                break
            }
        }

        // Split display into words for windowing.
        let words = display.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let windowSize = 12

        let snippetText: String
        if let anchorRange, !words.isEmpty {
            // Locate which word index the anchor falls in by counting words
            // before the anchor's lower bound.
            let prefix = display[display.startIndex..<anchorRange.lowerBound]
            let wordsBefore = prefix.split(separator: " ", omittingEmptySubsequences: true).count
            let half = windowSize / 2
            let start = max(0, wordsBefore - half)
            let end = min(words.count, start + windowSize)
            let realStart = max(0, end - windowSize)
            var window = words[realStart..<end].joined(separator: " ")
            if realStart > 0 { window = "…" + window }
            if end < words.count { window += "…" }
            snippetText = window
        } else {
            // No anchor — take the leading window.
            let end = min(words.count, windowSize)
            var window = words[0..<end].joined(separator: " ")
            if end < words.count { window += "…" }
            snippetText = window
        }

        // Compute highlight ranges within the snippet text for every token.
        var highlights: [Range<String.Index>] = []
        for token in tokens {
            var searchStart = snippetText.startIndex
            while searchStart < snippetText.endIndex,
                  let r = snippetText.range(
                      of: token,
                      options: [.caseInsensitive, .diacriticInsensitive],
                      range: searchStart..<snippetText.endIndex
                  ) {
                highlights.append(r)
                searchStart = r.upperBound > r.lowerBound ? r.upperBound : snippetText.index(after: r.lowerBound)
            }
        }
        return SearchSnippet(text: snippetText, highlightRanges: highlights)
    }
}

// MARK: - Levenshtein

/// Pure edit-distance helper, mirrored on Android. Two rolling rows; no
/// dependencies. `isWithin` short-circuits as soon as the best achievable
/// distance on a row exceeds `maxDistance`.
enum Levenshtein {

    /// Full Levenshtein distance between two strings (character-wise).
    static func distance(_ a: String, _ b: String) -> Int {
        let s = Array(a)
        let t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }

        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            current[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,       // deletion
                    current[j - 1] + 1,    // insertion
                    previous[j - 1] + cost // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[t.count]
    }

    /// True if the edit distance between `a` and `b` is ≤ `maxDistance`.
    /// Early-exits when a length gap alone already exceeds the bound, and when
    /// every cell of a row is already above the bound.
    static func isWithin(_ a: String, _ b: String, maxDistance: Int) -> Bool {
        if abs(a.count - b.count) > maxDistance { return false }
        let s = Array(a)
        let t = Array(b)
        if s.isEmpty { return t.count <= maxDistance }
        if t.isEmpty { return s.count <= maxDistance }

        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            current[0] = i
            var rowMin = current[0]
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
                rowMin = min(rowMin, current[j])
            }
            if rowMin > maxDistance { return false } // no path can recover
            swap(&previous, &current)
        }
        return previous[t.count] <= maxDistance
    }
}
