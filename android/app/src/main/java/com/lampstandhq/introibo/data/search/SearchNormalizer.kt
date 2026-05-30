package com.lampstandhq.introibo.data.search

import com.lampstandhq.introibo.data.model.strippingEm
import java.text.Normalizer
import java.util.Locale

// MARK: - SearchNormalizer
//
// The heart of cross-platform search parity. `fold` is used at BOTH
// index-build time and query time, so identical input MUST yield identical
// output on iOS and Android. The iOS mirror lives at:
//   Introibo/Data/Search/SearchNormalizer.swift
//
// Folding pipeline (order matters):
//   1. Strip em/br/HTML entities (reuse `strippingEm`).
//   2. Unicode NFD (canonical decomposition).
//   3. Remove combining marks (Unicode category Mn) — folds ALL
//      decomposing Latin-script diacritics automatically.
//   4. Apply the explicit ligature / non-decomposing map (SearchTables).
//   5. Lowercase, Locale.ROOT (locale-invariant).
//   6. Collapse runs of non-alphanumeric to a single space; trim.
//
// The parity guarantee is enforced by the golden-fixture test
// (search_golden.json) which both platforms run against this function.

object SearchNormalizer {

    private val combiningMarks = Regex("\\p{Mn}+")

    fun fold(input: String): String {
        // 1. Strip markup / HTML entities.
        val stripped = input.strippingEm

        // 2. NFD canonical decomposition.
        val decomposed = Normalizer.normalize(stripped, Normalizer.Form.NFD)

        // 3. Remove combining marks (category Mn).
        val noMarks = combiningMarks.replace(decomposed, "")

        // 4. Apply the ligature / non-decomposing map.
        val mapped = StringBuilder(noMarks.length)
        for (ch in noMarks) {
            val replacement = SearchTables.ligatureMap[ch]
            if (replacement != null) {
                mapped.append(replacement)
            } else {
                mapped.append(ch)
            }
        }

        // 5. Lowercase, locale-invariant.
        val lowered = mapped.toString().lowercase(Locale.ROOT)

        // 6. Collapse non-alphanumeric runs to a single space; trim.
        return collapseNonAlphanumeric(lowered)
    }

    /**
     * Replaces every maximal run of characters that are not Unicode letters or
     * digits with a single space, then trims. Letters and digits pass through
     * verbatim (already diacritic-free and lowercased by this point).
     */
    private fun collapseNonAlphanumeric(s: String): String {
        val out = StringBuilder(s.length)
        var pendingSpace = false
        var wroteAny = false
        for (ch in s) {
            if (ch.isLetter() || ch.isDigit()) {
                if (pendingSpace && wroteAny) out.append(' ')
                out.append(ch)
                wroteAny = true
                pendingSpace = false
            } else {
                pendingSpace = true
            }
        }
        return out.toString()
    }
}
