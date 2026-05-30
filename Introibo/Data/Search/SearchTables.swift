import Foundation

// MARK: - Cross-platform search tables
//
// DO NOT diverge across platforms.
// The Android mirror lives at:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchTables.kt
// Any edit here MUST be mirrored there (and vice versa), or the
// golden-fixture parity test (search_golden.json) will fail.
//
// This table only needs entries for characters that Unicode NFD does NOT
// decompose into base-letter + combining mark. Anything that decomposes
// (the vast majority of Latin-script diacritics: French é/è/ê, Portuguese
// ã/õ, Polish ą/ę, German ä/ö/ü, etc.) is handled automatically by the
// NFD + combining-mark-removal step in SearchNormalizer and must NOT be
// listed here.
//
// Adding a new language: if the language introduces a non-decomposing
// character (a ligature, a stroked letter, or an eszett-like glyph), add
// ONE row below in BOTH platform files. If its characters all decompose,
// add nothing — fold() already handles them.

enum SearchTables {

    /// Maps non-decomposing / ligature characters to their ASCII fold target.
    /// Keys are single scalars; values may be multi-character ("ae", "ss").
    /// Applied AFTER lowercasing-independent NFD + combining-mark removal but
    /// the map itself is case-folding too (both Æ and æ map to "ae") so it is
    /// robust whether applied before or after the lowercase step.
    static let ligatureMap: [Character: String] = [
        "æ": "ae", "Æ": "ae",
        "œ": "oe", "Œ": "oe",
        "ß": "ss",
        "ø": "o",  "Ø": "o",
        "ł": "l",  "Ł": "l",
        "đ": "d",  "Đ": "d",
        "ð": "d",  "Ð": "d",
        "þ": "th", "Þ": "th",
        // å DOES decompose under NFD; included for safety / belt-and-braces.
        "å": "a",  "Å": "a",
    ]
}
