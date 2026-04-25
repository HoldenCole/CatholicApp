import SwiftUI

private let USE_BUNDLED_FONTS = false

private enum FontFamily {
    static let display = "PlayfairDisplay"
    static let body    = "EBGaramond"
    static let label   = "CormorantGaramond"
}

extension Font {
    // MARK: - Display (Playfair Display)
    static let pageTitle = serif(family: FontFamily.display, size: 34, weight: .semibold, italic: true)
    static let titleXL   = serif(family: FontFamily.display, size: 28, weight: .semibold, italic: false)
    static let titleL    = serif(family: FontFamily.display, size: 22, weight: .semibold, italic: false)
    static let titleM    = serif(family: FontFamily.display, size: 18, weight: .medium,   italic: false)

    // MARK: - Body (EB Garamond) — scaled by font size preference
    static var body: Font     { scaledSerif(family: FontFamily.body, size: 16, weight: .regular, italic: false) }
    static var bodyIt: Font   { scaledSerif(family: FontFamily.body, size: 16, weight: .regular, italic: true) }
    static var bodySm: Font   { scaledSerif(family: FontFamily.body, size: 14, weight: .regular, italic: false) }

    // MARK: - Labels (Cormorant Garamond)
    static let label    = serif(family: FontFamily.label, size: 11, weight: .bold,   italic: true)
    static let caption  = serif(family: FontFamily.label, size: 12, weight: .regular, italic: true)
    static let captionSm = serif(family: FontFamily.label, size: 10, weight: .regular, italic: true)

    // MARK: - Helpers
    private static func serif(family: String, size: CGFloat, weight: Font.Weight, italic: Bool) -> Font {
        if USE_BUNDLED_FONTS {
            return .custom(family, size: size)
        }
        var f: Font = .system(size: size, weight: weight, design: .serif)
        if italic { f = f.italic() }
        return f
    }

    private static func scaledSerif(family: String, size: CGFloat, weight: Font.Weight, italic: Bool) -> Font {
        let scale = FontSizeScale.current()
        let scaled = size * scale
        if USE_BUNDLED_FONTS {
            return .custom(family, size: scaled)
        }
        var f: Font = .system(size: scaled, weight: weight, design: .serif)
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
