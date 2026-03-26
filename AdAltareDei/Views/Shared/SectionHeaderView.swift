import SwiftUI

struct SectionHeaderView: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            if let subtitle {
                Text(subtitle)
                    .font(.uiCaption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    SectionHeaderView(title: "Rosary Prayers", subtitle: "Rosarium")
}
