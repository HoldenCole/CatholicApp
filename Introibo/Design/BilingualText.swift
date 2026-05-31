import SwiftUI

struct BilingualLine: View {
    let lat: String
    let eng: String
    var sideBySide: Bool = false

    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }

    // Render the body through the inline-link parser. For a body with NO
    // `<link>` tags, LinkMarkup.runs returns a single `.text(body.strippingEm)`
    // run, so the AttributedString carries the exact same characters and no
    // attributes — i.e. visually identical to the previous `Text(strippingEm)`.
    private var attributedLat: AttributedString { ContextualLink.attributed(lat) }
    private var attributedEng: AttributedString { ContextualLink.attributed(eng) }

    var body: some View {
        if sideBySide && mode == .both && fontScale <= 1.4 {
            HStack(alignment: .top, spacing: 12) {
                Text(attributedLat)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(attributedEng)
                    .font(.body)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if mode != .vernacular {
                    Text(attributedLat)
                        .font(.body)
                        .foregroundStyle(Color.primaryText)
                        .lineSpacing(3)
                }
                if mode != .latinOnly {
                    Text(attributedEng)
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(3)
                }
            }
        }
    }
}

// MARK: - Contextual-link rendering (Phase 2)

/// Builds an `AttributedString` from inline `<link>` markup. Plain text runs are
/// appended verbatim; link runs carry an `introibo://link?t=…` URL plus
/// sanctuary-red + underline styling. Taps are dispatched by the app-root
/// `.onOpenURL` handler, which decodes `t` and calls `DeepLinkRouter`.
enum ContextualLink {

    /// The custom URL scheme inline links open. Registered in project.yml so
    /// `.onOpenURL` fires for these in-app taps.
    static let scheme = "introibo"
    static let host = "link"

    /// Builds the deep-link URL for a target, carrying the wire string as the
    /// `t` query item. `URLComponents` percent-encodes the value correctly —
    /// including any `#` in a positioned target (e.g. `prayer:ave#stanza-1`),
    /// which a manual `.urlQueryAllowed` encode would leave as a URL fragment.
    static func url(for target: DeepLinkTarget) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: "t", value: target.wireString)]
        return components.url
    }

    /// Parses `body` into runs and assembles an AttributedString. A link-free
    /// body yields a single plain run identical to `body.strippingEm`.
    static func attributed(_ body: String) -> AttributedString {
        var result = AttributedString("")
        for run in LinkMarkup.runs(body) {
            switch run {
            case .text(let s):
                result.append(AttributedString(s))
            case .link(let text, let target):
                var piece = AttributedString(text)
                if let url = url(for: target) {
                    piece.link = url
                }
                piece.foregroundColor = .sanctuaryRed
                piece.underlineStyle = .single
                result.append(piece)
            }
        }
        return result
    }
}

struct LanguageAwareText: View {
    let latin: String
    let english: String
    var separator: String = "  \u{00B7}  "
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }

    var body: some View {
        switch mode {
        case .latinOnly:
            Text(latin)
        case .vernacular:
            Text(english)
        case .both:
            VStack(spacing: 2) {
                Text(latin)
                Text(english)
            }
        }
    }
}
