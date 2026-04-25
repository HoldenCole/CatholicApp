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
    static let sanctuaryRed = Color(red: 139/255, green:  26/255, blue:  26/255)
    static let goldLeaf    = Color(red: 184/255, green: 150/255, blue:  12/255)
    static let walnut      = Color(red:  26/255, green:  19/255, blue:  12/255)
    static let walnutHi    = Color(red:  44/255, green:  32/255, blue:  21/255)
    static let ivory       = Color(red: 232/255, green: 223/255, blue: 201/255)

    // MARK: - Semantic tokens (dark-mode aware)
    // These pick light/dark variants automatically based on the user's
    // interface style. Views should prefer these over the raw palette.

    /// Page background — parchment (default), white (clean), or walnut (dark).
    static var pageBackground: Color {
        switch AppTheme.current() {
        case .parchment: return parchment
        case .white:     return Color.white
        case .dark:      return walnut
        }
    }

    /// Primary text — ink on light backgrounds, ivory on dark.
    static var primaryText: Color {
        switch AppTheme.current() {
        case .parchment: return ink
        case .white:     return ink
        case .dark:      return ivory
        }
    }

    /// Secondary text — sepia on light, muted on dark.
    static var secondaryText: Color {
        switch AppTheme.current() {
        case .parchment: return sepia
        case .white:     return sepia
        case .dark:      return muted
        }
    }

    /// Muted meta/label text.
    static var tertiaryText: Color {
        switch AppTheme.current() {
        case .parchment: return muted
        case .white:     return muted
        case .dark:      return sepia
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
