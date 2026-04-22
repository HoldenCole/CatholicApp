import SwiftUI

// Typography tokens. The prototype uses three serifs:
//   - Playfair Display  (display titles, illuminated numerals)
//   - EB Garamond       (body prose)
//   - Cormorant Garamond (italic labels, meta text, Latin subtitles)
//
// The real fonts will be bundled in a later batch. For now we use the
// iOS system serif stack, which gives a solid classical feel on iOS 17+
// without requiring font registration. Once .ttf files are bundled,
// flip USE_BUNDLED_FONTS to true and the whole app picks them up.

private let USE_BUNDLED_FONTS = false

// Family names used when the .ttf files ship with the app.
private enum FontFamily {
    static let display = "PlayfairDisplay"
    static let body    = "EBGaramond"
    static let label   = "CormorantGaramond"
}

extension Font {
    // MARK: - Display (Playfair Display)
    /// 34pt italic — page titles inside dark-walnut headers.
    static let pageTitle = serif(family: FontFamily.display, size: 34, weight: .semibold, italic: true)
    /// 28pt — large illuminated headings (e.g. "Monday" on Today).
    static let titleXL   = serif(family: FontFamily.display, size: 28, weight: .semibold, italic: false)
    /// 22pt — section headings.
    static let titleL    = serif(family: FontFamily.display, size: 22, weight: .semibold, italic: false)
    /// 18pt — sub-section headings.
    static let titleM    = serif(family: FontFamily.display, size: 18, weight: .medium,   italic: false)

    // MARK: - Body (EB Garamond)
    static let body     = serif(family: FontFamily.body, size: 16, weight: .regular, italic: false)
    static let bodyIt   = serif(family: FontFamily.body, size: 16, weight: .regular, italic: true)
    static let bodySm   = serif(family: FontFamily.body, size: 14, weight: .regular, italic: false)

    // MARK: - Labels (Cormorant Garamond)
    /// 11pt uppercase, italic — "Ritus · Missale Romanum 1962" style labels.
    static let label    = serif(family: FontFamily.label, size: 11, weight: .bold,   italic: true)
    /// 12pt italic — Latin subtitles, card supplementary text.
    static let caption  = serif(family: FontFamily.label, size: 12, weight: .regular, italic: true)
    /// 10pt italic — smallest meta rows (feria lines, date stamps).
    static let captionSm = serif(family: FontFamily.label, size: 10, weight: .regular, italic: true)

    // MARK: - Helper
    private static func serif(family: String, size: CGFloat, weight: Font.Weight, italic: Bool) -> Font {
        if USE_BUNDLED_FONTS {
            return .custom(family, size: size)
        }
        var f: Font = .system(size: size, weight: weight, design: .serif)
        if italic { f = f.italic() }
        return f
    }
}

// Convenience view modifier for the common "small uppercase italic label"
// pattern that repeats all over the prototype.
struct SmallLabelStyle: ViewModifier {
    var color: Color = Color.tertiaryText
    var tracking: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .font(.label)
            .foregroundStyle(color)
            .textCase(.uppercase)
            .tracking(tracking)
    }
}

extension View {
    /// Applies the "small uppercase italic label" styling — gold/muted,
    /// tracked letter-spacing, italic serif. Use for rubric labels, meta
    /// rows, category captions.
    func smallLabel(color: Color = Color.tertiaryText, tracking: CGFloat = 2.5) -> some View {
        modifier(SmallLabelStyle(color: color, tracking: tracking))
    }
}
