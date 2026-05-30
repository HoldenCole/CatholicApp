import Foundation

// MARK: - SearchNormalizer
//
// The heart of cross-platform search parity. `fold` is used at BOTH
// index-build time and query time, so identical input MUST yield identical
// output on iOS and Android. The Android mirror lives at:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchNormalizer.kt
//
// Folding pipeline (order matters):
//   1. Strip em/br/HTML entities (reuse `strippingEm`).
//   2. Unicode NFD (canonical decomposition).
//   3. Remove combining marks (Unicode category Mn) — folds ALL
//      decomposing Latin-script diacritics automatically.
//   4. Apply the explicit ligature / non-decomposing map (SearchTables).
//   5. Lowercase, locale-invariant.
//   6. Collapse runs of non-alphanumeric to a single space; trim.
//
// The parity guarantee is enforced by the golden-fixture test
// (search_golden.json) which both platforms run against this function.

enum SearchNormalizer {

    static func fold(_ input: String) -> String {
        // 1. Strip markup / HTML entities.
        let stripped = input.strippingEm

        // 2. NFD canonical decomposition.
        let decomposed = stripped.decomposedStringWithCanonicalMapping

        // 3. Remove combining marks (Unicode category Mn), operating on
        //    SCALARS — not graphemes. This MUST happen before the ligature map
        //    so a combining-mark-bearing ligature (e.g. "ǽ" = æ + ´) decomposes
        //    to bare "æ" and then maps to "ae", matching Android's
        //    \p{Mn}-removal-then-map order exactly. (Mapping on graphemes first
        //    would leave "ǽ" unmapped and diverge from Android.)
        let combining = CharacterSet.combiningMarks
        var noMarks = String.UnicodeScalarView()
        noMarks.reserveCapacity(decomposed.unicodeScalars.count)
        for scalar in decomposed.unicodeScalars where !combining.contains(scalar) {
            noMarks.append(scalar)
        }

        // 4. Apply the ligature / non-decomposing map, per scalar.
        var folded = String.UnicodeScalarView()
        folded.reserveCapacity(noMarks.count)
        for scalar in noMarks {
            if let mapped = SearchTables.ligatureMap[Character(scalar)] {
                folded.append(contentsOf: mapped.unicodeScalars)
            } else {
                folded.append(scalar)
            }
        }
        var result = String(folded)

        // 5. Lowercase, locale-invariant (nil locale == invariant).
        result = result.lowercased()

        // 6. Collapse non-alphanumeric runs to a single space; trim.
        result = collapseNonAlphanumeric(result)
        return result
    }

    /// Replaces every maximal run of characters that are not ASCII/Unicode
    /// letters or digits with a single space, then trims leading/trailing
    /// spaces. Letters and digits are kept verbatim (already diacritic-free
    /// and lowercased by this point).
    private static func collapseNonAlphanumeric(_ s: String) -> String {
        var out = String()
        out.reserveCapacity(s.count)
        var pendingSpace = false
        var wroteAny = false
        for ch in s {
            if ch.isLetter || ch.isNumber {
                if pendingSpace && wroteAny { out.append(" ") }
                out.append(ch)
                wroteAny = true
                pendingSpace = false
            } else {
                pendingSpace = true
            }
        }
        return out
    }
}
