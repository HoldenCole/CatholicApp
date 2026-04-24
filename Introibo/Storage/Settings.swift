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
        case .rite1962: return "1962 Missal (Roncalli)"
        case .rite1955: return "1955 Holy Week reforms"
        case .pre1955:  return "Pre-1955 rubrics"
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
        case .discipline1962: return "1962 discipline"
        case .discipline1917: return "1917 Code"
        case .strict:         return "Stricter (pre-Pius XII)"
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
}

// App theme: parchment (warm default), white (clean), dark (walnut).
enum AppTheme: String, CaseIterable, Identifiable {
    case parchment = "parchment"
    case white     = "white"
    case dark      = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .parchment: return "Parchment"
        case .white:     return "Clean White"
        case .dark:      return "Dark (Walnut)"
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
