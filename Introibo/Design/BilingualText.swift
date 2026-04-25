import SwiftUI

// Renders Latin and/or English text based on the user's language
// preference. Used across Missal, Prayers, Office, and Stations.

struct BilingualLine: View {
    let lat: String
    let eng: String
    var sideBySide: Bool = false

    private var mode: LanguageMode { .current() }
    private var cleanLat: String { lat.strippingEm }
    private var cleanEng: String { eng.strippingEm }

    var body: some View {
        if sideBySide && mode == .both {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(cleanLat)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(cleanEng)
                    .font(.bodySm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                        .font(.bodySm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(2)
                }
            }
        }
    }
}
