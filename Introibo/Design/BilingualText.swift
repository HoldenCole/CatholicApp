import SwiftUI

// Renders Latin and/or English text based on the user's language
// preference. Used across Missal, Prayers, Office, and Stations.

struct BilingualLine: View {
    let lat: String
    let eng: String
    var sideBySide: Bool = false

    private var mode: LanguageMode { .current() }

    private var isShort: Bool {
        lat.count + eng.count < 120
    }

    var body: some View {
        if sideBySide && mode == .both && isShort {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(lat)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(eng)
                    .font(.bodySm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                if mode != .vernacular {
                    Text(lat)
                        .font(.body)
                        .foregroundStyle(Color.primaryText)
                        .lineSpacing(3)
                }
                if mode != .latinOnly {
                    Text(eng)
                        .font(.bodySm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(2)
                }
            }
        }
    }
}
