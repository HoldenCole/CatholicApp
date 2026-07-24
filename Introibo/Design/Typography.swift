import SwiftUI
import UIKit

private let USE_BUNDLED_FONTS = false

private enum FontFamily {
    static let display = "PlayfairDisplay"
    static let body    = "EBGaramond"
    static let label   = "CormorantGaramond"
}

// MARK: - Accessible type ramp
//
// EVERY size in the app passes through `a11y(_:relativeTo:)`, which applies
// BOTH accessibility inputs:
//   1. the in-app text-size slider (FontSizeScale), and
//   2. the iOS system-wide Dynamic Type setting, via UIFontMetrics.
// Titles and labels used to be pinned ("fixed size, not scaled") — which left
// low-vision users unable to enlarge headings with either slider. Nothing is
// pinned any more; small decorative text scales too, and views cope via
// lineLimit/minimumScaleFactor and flexible stacks.

/// A point size scaled by the in-app slider and by Dynamic Type.
func a11y(_ size: CGFloat, relativeTo style: UIFont.TextStyle = .body) -> CGFloat {
    let inApp = size * FontSizeScale.current()
    return UIFontMetrics(forTextStyle: style).scaledValue(for: inApp)
}

extension Font {
    // MARK: - Display (Playfair Display)
    static var pageTitle: Font { serif(family: FontFamily.display, size: a11y(34, relativeTo: .largeTitle), weight: .semibold, italic: true) }
    static var titleXL: Font   { serif(family: FontFamily.display, size: a11y(28, relativeTo: .title1), weight: .semibold, italic: false) }
    static var titleL: Font    { serif(family: FontFamily.display, size: a11y(22, relativeTo: .title2), weight: .semibold, italic: false) }
    static var titleM: Font    { serif(family: FontFamily.display, size: a11y(18, relativeTo: .headline), weight: .medium, italic: false) }

    // MARK: - Body (EB Garamond)
    static var body: Font     { serif(family: FontFamily.body, size: a11y(16), weight: .regular, italic: false) }
    static var bodyIt: Font   { serif(family: FontFamily.body, size: a11y(16), weight: .regular, italic: true) }
    static var bodySm: Font   { serif(family: FontFamily.body, size: a11y(14, relativeTo: .callout), weight: .regular, italic: false) }

    // MARK: - Labels (Cormorant Garamond)
    static var label: Font    { serif(family: FontFamily.label, size: a11y(11, relativeTo: .caption1), weight: .bold, italic: true) }
    static var caption: Font  { serif(family: FontFamily.label, size: a11y(12, relativeTo: .caption1), weight: .regular, italic: true) }
    static var captionSm: Font { serif(family: FontFamily.label, size: a11y(10, relativeTo: .caption2), weight: .regular, italic: true) }

    // MARK: - Inline sizes (icons, chrome, decorative text)
    //
    // Drop-in replacements for `.system(size:)` so every inline-sized glyph
    // and text follows both text-size controls.
    static func scaledSystem(_ size: CGFloat) -> Font {
        .system(size: a11y(size), design: .default)
    }
    static func scaledSystem(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: a11y(size), weight: weight, design: .default)
    }
    static func scaledSystem(_ size: CGFloat, weight: Font.Weight, design: Font.Design) -> Font {
        .system(size: a11y(size), weight: weight, design: design)
    }
    static func scaledSystem(_ size: CGFloat, design: Font.Design) -> Font {
        .system(size: a11y(size), design: design)
    }

    // MARK: - Helpers
    private static func serif(family: String, size: CGFloat, weight: Font.Weight, italic: Bool) -> Font {
        if USE_BUNDLED_FONTS {
            return .custom(family, size: size)
        }
        var f: Font = .system(size: size, weight: weight, design: .serif)
        if italic { f = f.italic() }
        return f
    }
}

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
    func smallLabel(color: Color = Color.tertiaryText, tracking: CGFloat = 2.5) -> some View {
        modifier(SmallLabelStyle(color: color, tracking: tracking))
    }
}
