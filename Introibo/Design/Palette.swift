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
    static let sepia     = Color(red: 122/255, green: 106/255, blue:  88/255)
    static let muted     = Color(red: 154/255, green: 134/255, blue: 112/255)
    static let sanctuaryRed = Color(red: 139/255, green:  26/255, blue:  26/255)
    static let goldLeaf    = Color(red: 184/255, green: 150/255, blue:  12/255)
    static let walnut      = Color(red:  26/255, green:  19/255, blue:  12/255)
    static let walnutHi    = Color(red:  44/255, green:  32/255, blue:  21/255)
    static let ivory       = Color(red: 232/255, green: 223/255, blue: 201/255)

    // MARK: - Semantic tokens (dark-mode aware)
    // These pick light/dark variants automatically based on the user's
    // interface style. Views should prefer these over the raw palette.

    /// Page background — parchment in light, walnut in dark.
    static let pageBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red:  26/255, green:  19/255, blue:  12/255, alpha: 1)
            : UIColor(red: 242/255, green: 232/255, blue: 208/255, alpha: 1)
    })

    /// Primary text — ink in light, ivory in dark.
    static let primaryText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 232/255, green: 223/255, blue: 201/255, alpha: 1)
            : UIColor(red:  28/255, green:  20/255, blue:  16/255, alpha: 1)
    })

    /// Secondary text — sepia in light, muted in dark.
    static let secondaryText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 154/255, green: 134/255, blue: 112/255, alpha: 1)
            : UIColor(red: 122/255, green: 106/255, blue:  88/255, alpha: 1)
    })

    /// Muted meta/label text — the Latin subtitles, date stamps, etc.
    static let tertiaryText = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 122/255, green: 106/255, blue:  88/255, alpha: 1)
            : UIColor(red: 154/255, green: 134/255, blue: 112/255, alpha: 1)
    })

    /// Page frame hairline — gold, dimmer in dark mode.
    static let frameLine = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 184/255, green: 150/255, blue:  12/255, alpha: 0.25)
            : UIColor(red: 184/255, green: 150/255, blue:  12/255, alpha: 0.3)
    })
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
