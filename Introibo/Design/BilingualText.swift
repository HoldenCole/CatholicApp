import SwiftUI

// Renders Latin and/or English text based on the user's language
// preference. Used across Missal, Prayers, Office, and Stations.

struct BilingualLine: View {
    let lat: String
    let eng: String
    var sideBySide: Bool = false

    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var cleanLat: String { lat.strippingEm }
    private var cleanEng: String { eng.strippingEm }

    var body: some View {
        if sideBySide && mode == .both {
            if fontScale > 1.4 {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 16) {
                        Text(cleanLat)
                            .font(.body)
                            .foregroundStyle(Color.primaryText)
                            .lineSpacing(3)
                            .frame(width: UIScreen.main.bounds.width * 0.78, alignment: .leading)
                        Text(cleanEng)
                            .font(.body)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                            .lineSpacing(3)
                            .frame(width: UIScreen.main.bounds.width * 0.78, alignment: .leading)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Text(cleanLat)
                        .font(.body)
                        .foregroundStyle(Color.primaryText)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(cleanEng)
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if mode != .vernacular {
                    Text(cleanLat)
                        .font(.body)
                        .foregroundStyle(Color.primaryText)
                        .lineSpacing(3)
                }
                if mode != .latinOnly {
                    Text(cleanEng)
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(3)
                }
            }
        }
    }
}

/// Helper to conditionally show Latin and/or English text based on
/// the user's language preference. Use anywhere that raw Text() is
/// shown for bilingual content instead of BilingualLine.
struct LanguageAwareText: View {
    let latin: String
    let english: String
    var separator: String = "  \u{00B7}  "
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }

    var resolved: String {
        switch mode {
        case .latinOnly: return latin
        case .vernacular: return english
        case .both: return "\(latin)\(separator)\(english)"
        }
    }

    var body: some View {
        Text(resolved)
    }
}
