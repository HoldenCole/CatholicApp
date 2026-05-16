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
        if sideBySide && mode == .both && fontScale <= 1.4 {
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
