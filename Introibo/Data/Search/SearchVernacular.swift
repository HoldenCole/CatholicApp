import Foundation

// MARK: - SearchVernacular (Phase 1: index core)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchVernacular.kt
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
//   `keys` below is the single source of truth for "which vernacular fields
//   exist." Extractors iterate it; they never name `.eng` directly. When the
//   content model gains an `es` / `fr` / `it` field:
//     1. add the field to the model(s),
//     2. add its key to `keys` here (ONE line),
//     3. teach each `Translatable` to return that field in its `vernaculars`
//        map (the models are the only place a field name appears).
//   No extractor changes. No normalizer changes (fold() is language-agnostic
//   NFD and already folds every Latin-script diacritic automatically).
//
// NOTE ON LanguageMode (Latin-only / Vernacular-only / Both):
//   "Vernacular" there resolves to the user's single selected language. The
//   set of *available* vernaculars is what grows over time; the mode itself
//   stays a three-way choice. Indexing is deliberately mode-independent — we
//   index all vernaculars so any future selection is searchable.

enum SearchVernacular {

    /// The ordered list of vernacular field keys present in the content model.
    /// CURRENTLY: just English. Add a language by appending its key here (and
    /// returning the field from each model's `vernaculars` map). This is the
    /// "one line to extend" referenced throughout the search code.
    ///
    /// e.g. future: ["eng", "es", "fr", "it"]
    static let keys: [String] = ["eng"]
}

/// A model fragment that carries Latin plus its (one-per-language) vernacular
/// fields. The Latin is always present conceptually; the `vernaculars` map is
/// keyed by `SearchVernacular.keys`. Implementations return every vernacular
/// field they hold — extractors then collect `lat` + all present vernaculars
/// without ever naming a specific language.
protocol Translatable {
    /// Latin text (always indexed). `nil`/empty is tolerated.
    var latText: String? { get }
    /// Vernacular text keyed by `SearchVernacular` key. Missing keys are fine.
    var vernaculars: [String: String?] { get }
}

extension Translatable {
    /// `lat` + every vernacular field, in `SearchVernacular.keys` order, as a
    /// flat list of optionals ready for `collectText`. This is the choke point
    /// that makes the whole pipeline language-generic.
    var translatableFields: [String?] {
        var out: [String?] = [latText]
        for key in SearchVernacular.keys {
            // `[key]` is `String??`; flatten the outer optional (absent key).
            if let value = vernaculars[key] { out.append(value) }
        }
        return out
    }
}
