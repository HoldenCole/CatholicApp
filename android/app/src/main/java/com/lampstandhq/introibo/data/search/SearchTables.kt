package com.lampstandhq.introibo.data.search

// MARK: - Cross-platform search tables
//
// DO NOT diverge across platforms.
// The iOS mirror lives at:
//   Introibo/Data/Search/SearchTables.swift
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

object SearchTables {

    /**
     * Maps non-decomposing / ligature characters to their ASCII fold target.
     * Keys are single characters; values may be multi-character ("ae", "ss").
     * Both cases of each glyph are listed (Æ and æ both map to "ae") so the
     * map is robust whether applied before or after lowercasing.
     */
    val ligatureMap: Map<Char, String> = mapOf(
        'æ' to "ae", 'Æ' to "ae",
        'œ' to "oe", 'Œ' to "oe",
        'ß' to "ss",
        'ø' to "o", 'Ø' to "o",
        'ł' to "l", 'Ł' to "l",
        'đ' to "d", 'Đ' to "d",
        'ð' to "d", 'Ð' to "d",
        'þ' to "th", 'Þ' to "th",
        // å DOES decompose under NFD; included for safety / belt-and-braces.
        'å' to "a", 'Å' to "a",
    )
}
