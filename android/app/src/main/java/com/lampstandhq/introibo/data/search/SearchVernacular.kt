package com.lampstandhq.introibo.data.search

// MARK: - SearchVernacular (Phase 1: index core)
//
// Mirror of:
//   Introibo/Data/Search/SearchVernacular.swift
//
// THE CONTENT MODEL, IN ONE SENTENCE:
//   The app always shows Latin (`lat`, constant for every user) plus ONE
//   vernacular that the user has selected (English now; later Spanish, French,
//   Italian, …). It never shows two vernaculars at once — adding a language
//   means adding a NEW *selectable* vernacular, not a second column.
//
// WHY THIS FILE EXISTS:
//   Search must work no matter which vernacular the user has active, AND a
//   future Spanish user must be able to find Spanish text, a French user
//   French text, etc. So the index collects `lat` + EVERY vernacular field
//   that exists in the data, regardless of the active selection.
//
//   [keys] below is the single source of truth for "which vernacular fields
//   exist." Extractors iterate it; they never name `eng` directly. When the
//   content model gains an `es` / `fr` / `it` field:
//     1. add the field to the model(s),
//     2. add its key to [keys] here (ONE line),
//     3. teach each [Translatable] to return that field in its `vernaculars`
//        map (the models are the only place a field name appears).
//   No extractor changes. No normalizer changes (fold() is language-agnostic
//   NFD and already folds every Latin-script diacritic automatically).
//
// DO NOT diverge across platforms: the Android mirror must list the same keys
// in the same order as iOS, or `searchText` would differ between platforms.

object SearchVernacular {

    /**
     * The ordered list of vernacular field keys present in the content model.
     * CURRENTLY: just English. Add a language by appending its key here (and
     * returning the field from each model's `vernaculars` map). This is the
     * "one line to extend" referenced throughout the search code.
     *
     * e.g. future: listOf("eng", "es", "fr", "it")
     */
    val keys: List<String> = listOf("eng")
}

/**
 * A model fragment that carries Latin plus its (one-per-language) vernacular
 * fields. The Latin is always present conceptually; the [vernaculars] map is
 * keyed by [SearchVernacular.keys]. Implementations return every vernacular
 * field they hold — extractors then collect `lat` + all present vernaculars
 * without ever naming a specific language.
 */
interface Translatable {
    /** Latin text (always indexed). null/empty is tolerated. */
    val latText: String?

    /** Vernacular text keyed by [SearchVernacular] key. Missing keys are fine. */
    val vernaculars: Map<String, String?>
}

/**
 * `lat` + every vernacular field, in [SearchVernacular.keys] order, as a flat
 * list of nullable strings ready for `collectText`. This is the choke point
 * that makes the whole pipeline language-generic.
 */
val Translatable.translatableFields: List<String?>
    get() {
        val out = mutableListOf<String?>(latText)
        for (key in SearchVernacular.keys) {
            if (vernaculars.containsKey(key)) out.add(vernaculars[key])
        }
        return out
    }
