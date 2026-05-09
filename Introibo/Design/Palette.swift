import SwiftUI

// Centralised design tokens. These are the canonical colour values from
// the prototype's stylesheet — do not invent new ones. See prototype/SCHEMA.md.
//
// Raw palette (invariant across light/dark):
//   parchment  #F2E8D0   warm vellum
//   ink        #1C1410   warm black
//   sepia      #7A6A58   body italic / descriptions
//   muted      #9A8670   meta text, Latin subtitles
//   red        #8B1A1A   sanctuary red (primary accent)
//   gold       #B8960C   gold leaf (ornaments only)
//   walnut     #1A130C   deep walnut (header gradient start, dark-mode bg)
//   walnutHi   #2C2015   walnut gradient end
//   ivory      #E8DFC9   antique ivory (dark-mode text)

extension Color {
    // MARK: - Raw tokens
    static let parchment = Color(red: 242/255, green: 232/255, blue: 208/255)
    static let ink       = Color(red:  28/255, green:  20/255, blue:  16/255)
    static let sepia     = Color(red:  90/255, green:  74/255, blue:  58/255)
    static let muted     = Color(red: 154/255, green: 134/255, blue: 112/255)
    static let goldLeaf    = Color(red: 184/255, green: 150/255, blue:  12/255)
    static let walnut      = Color(red:  26/255, green:  19/255, blue:  12/255)
    static let walnutHi    = Color(red:  44/255, green:  32/255, blue:  21/255)
    static let ivory       = Color(red: 232/255, green: 223/255, blue: 201/255)

    private static var darkness: Double {
        UserDefaults.standard.double(forKey: "settings.textDarkness")
    }

    // MARK: - Theme-aware accent
    static var sanctuaryRed: Color {
        switch AppTheme.current() {
        case .dark: return Color(red: 220/255, green: 90/255, blue: 90/255)
        default:    return Color(red: 139/255, green: 26/255, blue: 26/255)
        }
    }

    // MARK: - Semantic tokens (dark-mode aware)

    /// Page background
    static var pageBackground: Color {
        switch AppTheme.current() {
        case .parchment: return parchment
        case .white:     return Color.white
        case .dark:      return walnut
        }
    }

    /// Primary text — darkness slider makes it bolder on light, brighter on dark.
    static var primaryText: Color {
        let d = darkness
        switch AppTheme.current() {
        case .parchment: return Color(red: max(28 - d * 56, 0)/255, green: max(20 - d * 40, 0)/255, blue: max(16 - d * 32, 0)/255)
        case .white:     return Color(red: max(28 - d * 56, 0)/255, green: max(20 - d * 40, 0)/255, blue: max(16 - d * 32, 0)/255)
        case .dark:      return Color(red: min(240 + d * 30, 255)/255, green: min(233 + d * 30, 255)/255, blue: min(215 + d * 30, 255)/255)
        }
    }

    /// Secondary text
    static var secondaryText: Color {
        let d = darkness
        switch AppTheme.current() {
        case .parchment: return Color(red: max(90 - d * 80, 20)/255, green: max(74 - d * 66, 14)/255, blue: max(58 - d * 52, 10)/255)
        case .white:     return Color(red: max(90 - d * 80, 20)/255, green: max(74 - d * 66, 14)/255, blue: max(58 - d * 52, 10)/255)
        case .dark:      return Color(red: min(185 + d * 40, 230)/255, green: min(168 + d * 36, 220)/255, blue: min(145 + d * 30, 200)/255)
        }
    }

    /// Muted meta/label text.
    static var tertiaryText: Color {
        switch AppTheme.current() {
        case .parchment: return muted
        case .white:     return muted
        case .dark:      return Color(red: 155/255, green: 137/255, blue: 115/255)
        }
    }

    /// Page frame hairline.
    static var frameLine: Color {
        switch AppTheme.current() {
        case .dark: return goldLeaf.opacity(0.25)
        default:    return goldLeaf.opacity(0.3)
        }
    }
}

// Liturgical colours (not theme-aware — always the same hue).
enum LiturgicalColour: String {
    case violet, rose, white, red, green

    var swiftUIColor: Color {
        switch self {
        case .violet: return Color(red: 106/255, green:  53/255, blue: 154/255)
        case .rose:   return Color(red: 160/255, green:  72/255, blue:  96/255)
        case .white:  return Color(red: 122/255, green:  90/255, blue:  14/255)
        case .red:    return Color.sanctuaryRed
        case .green:  return Color(red:  58/255, green:  93/255, blue:  40/255)
        }
    }
}
