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
    //
    // Rubrics, part headers, glosses and ℣/℟ responses all render in these
    // roles, so they sit at 0.75× body rather than the 0.63× they used to —
    // any smaller and the text-size slider never brings them to legibility.
    static var label: Font    { serif(family: FontFamily.label, size: a11y(12, relativeTo: .caption1), weight: .bold, italic: true) }
    static var caption: Font  { serif(family: FontFamily.label, size: a11y(13, relativeTo: .caption1), weight: .regular, italic: true) }
    static var captionSm: Font { serif(family: FontFamily.label, size: a11y(12, relativeTo: .caption2), weight: .regular, italic: true) }

    // System text-style names that stray call sites may still use: route
    // them through the ramp so they follow the slider too.
    static var subheadline: Font { bodySm }
    static var headline: Font { titleM }
    static var footnote: Font { caption }
    static var caption2: Font { captionSm }

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

// MARK: - Live invalidation
//
// `a11y` reads the slider value from UserDefaults at font-construction
// time, so a view only picks up a new size when its body re-runs. Rather
// than making every screen declare @AppStorage(fontSize), this modifier
// owns that dependency: the Font is built lazily inside a body that
// re-evaluates whenever the slider moves. Use `.appFont(.x)` wherever
// `.font(.x)` would otherwise sit.
struct AppFontModifier: ViewModifier {
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    let make: () -> Font

    func body(content: Content) -> some View {
        // Reading the stored scale registers the dependency.
        let _ = fontScale
        return content.font(make())
    }
}

extension View {
    func appFont(_ font: @autoclosure @escaping () -> Font) -> some View {
        modifier(AppFontModifier(make: font))
    }
}

struct SmallLabelStyle: ViewModifier {
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    var color: Color = Color.tertiaryText
    var tracking: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .font(.label)
            .foregroundStyle(color)
            .textCase(.uppercase)
            // Letter-spacing grows with the type so wide tracking never
            // reads as gaps between tiny glyphs.
            .tracking(tracking * CGFloat(fontScale) / CGFloat(FontSizeScale.defaultValue))
    }
}

extension View {
    func smallLabel(color: Color = Color.tertiaryText, tracking: CGFloat = 2.5) -> some View {
        modifier(SmallLabelStyle(color: color, tracking: tracking))
    }
}
