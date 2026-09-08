import SwiftUI

// User-facing settings. Persisted via @AppStorage so every view that
// declares the same key stays in sync automatically. All keys live
// under the `settings.*` prefix to match the prototype's aad.settings.*
// (we dropped the aad prefix since Introibo has its own bundle).

enum MissalRite: String, CaseIterable, Identifiable {
    case rite1962  = "1962"
    case rite1955  = "1955"
    case pre1955   = "pre1955"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rite1962: return ContentStore.shared.uiString("settings.rite.1962", "1962 Missal (Roncalli)")
        case .rite1955: return ContentStore.shared.uiString("settings.rite.1955", "1955 Holy Week reforms")
        case .pre1955:  return ContentStore.shared.uiString("settings.rite.pre1955", "Pre-1955 rubrics")
        }
    }

    var short: String {
        switch self {
        case .rite1962: return "Missále Romanum 1962"
        case .rite1955: return "Missále Romanum 1955"
        case .pre1955:  return "Missále Romanum pre-1955"
        }
    }
}

enum PenanceDiscipline: String, CaseIterable, Identifiable {
    case discipline1962 = "1962"
    case discipline1917 = "1917"
    case strict         = "strict"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discipline1962: return ContentStore.shared.uiString("settings.penance.1962", "1962 discipline")
        case .discipline1917: return ContentStore.shared.uiString("settings.penance.1917", "1917 Code")
        case .strict:         return ContentStore.shared.uiString("settings.penance.strict", "Stricter (pre-Pius XII)")
        }
    }

    var short: String {
        switch self {
        case .discipline1962: return "Codex 1962"
        case .discipline1917: return "Codex 1917"
        case .strict:         return "Discipline stricta"
        }
    }
}

// Keys — defined as typed wrappers so views can't misspell them.
enum SettingsKey {
    static let rite      = "settings.rite"
    static let penance   = "settings.penance"
    static let darkMode  = "settings.darkMode"
    static let theme     = "settings.theme"
    static let language  = "settings.language"
    static let fontSize  = "settings.fontSize"
    static let fontRange = "settings.fontRange"
    static let textDarkness = "settings.textDarkness"
    static let showLeoninePrayers = "settings.showLeoninePrayers"
    static let showUpcomingFeasts = "settings.showUpcomingFeasts"
    /// Read the Martyrology in the second part of Prime (on by default).
    static let primeMartyrology = "settings.primeMartyrology"
    static let vernacularLang = "settings.vernacularLang"
}

enum FontRange: String, CaseIterable, Identifiable {
    case smaller = "smaller"
    case normal  = "normal"
    case bigger  = "bigger"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .smaller: return ContentStore.shared.uiString("settings.font.smaller", "Smaller")
        case .normal:  return ContentStore.shared.uiString("settings.font.normal", "Normal")
        case .bigger:  return ContentStore.shared.uiString("settings.font.bigger", "Bigger")
        }
    }

    var min: Double {
        switch self {
        case .smaller: return 0.7
        case .normal:  return 1.0
        case .bigger:  return 1.3
        }
    }

    var max: Double {
        switch self {
        case .smaller: return 1.1
        case .normal:  return 1.5
        case .bigger:  return 2.0
        }
    }

    var defaultVal: Double {
        switch self {
        case .smaller: return 0.85
        case .normal:  return 1.15
        case .bigger:  return 1.5
        }
    }

    static func current() -> FontRange {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.fontRange) ?? "normal"
        return FontRange(rawValue: raw) ?? .normal
    }
}

enum FontSizeScale {
    static let min: Double = 0.7
    static let max: Double = 2.0
    static let defaultValue: Double = 1.15

    static func current() -> CGFloat {
        let val = UserDefaults.standard.double(forKey: SettingsKey.fontSize)
        if val < Self.min || val > Self.max { return Self.defaultValue }
        return CGFloat(val)
    }
}

enum LanguageMode: String, CaseIterable, Identifiable {
    case both      = "both"
    case latinOnly = "latin"
    case vernacular = "vernacular"

    var id: String { rawValue }

    var label: String {
        let v = VernacularLanguage.current().displayName
        switch self {
        case .both:       return ContentStore.shared.uiString("settings.language.both", "Latin & {0}", v)
        case .latinOnly:  return ContentStore.shared.uiString("settings.language.latin", "Latin Only")
        case .vernacular: return ContentStore.shared.uiString("settings.language.vernacular", "{0} Only", v)
        }
    }

    static func current() -> LanguageMode {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.language) ?? "both"
        return LanguageMode(rawValue: raw) ?? .both
    }
}

// Which vernacular the eng-side of every bilingual surface shows. Spanish
// coverage is the overlay in *_es.json (prayers, Marian antiphons, hour
// metadata); anything not covered falls back to English.
enum VernacularLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }

    static func current() -> VernacularLanguage {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.vernacularLang) ?? "en"
        return VernacularLanguage(rawValue: raw) ?? .english
    }
}

// App theme: parchment (warm default), white (clean), dark (walnut).
enum AppTheme: String, CaseIterable, Identifiable {
    case parchment = "parchment"
    case white     = "white"
    case dark      = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parchment: return ContentStore.shared.uiString("settings.theme.parchment", "Parchment")
        case .white:     return ContentStore.shared.uiString("settings.theme.white", "Clean White")
        case .dark:      return ContentStore.shared.uiString("settings.theme.dark", "Dark (Walnut)")
        }
    }

    var latin: String {
        switch self {
        case .parchment: return "Membrana"
        case .white:     return "Candida"
        case .dark:      return "Obscura"
        }
    }

    static func current() -> AppTheme {
        // Check legacy dark mode key first for backwards compatibility
        let legacy = UserDefaults.standard.bool(forKey: SettingsKey.darkMode)
        let raw = UserDefaults.standard.string(forKey: SettingsKey.theme) ?? (legacy ? "dark" : "parchment")
        return AppTheme(rawValue: raw) ?? .parchment
    }
}

// Property-wrapper helpers. Usage inside a View:
//     @AppStorage(SettingsKey.rite) var rite: MissalRite = .rite1962
// But @AppStorage doesn't natively bind a RawRepresentable enum, so we
// expose a small wrapper that does the round-trip string <-> enum.

extension AppStorage where Value == String {
    // `@AppStorage` already supports String directly; use that for rite
    // and penance by storing the raw value, and convert at read sites.
}
