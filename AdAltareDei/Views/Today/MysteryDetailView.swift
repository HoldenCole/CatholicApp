import SwiftUI

struct MysteryDetailView: View {
    let mystery: Mystery

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(mystery.latinTitle)
                        .font(.latinDisplay)
                        .foregroundStyle(.ink)

                    Text(mystery.englishTitle)
                        .font(.englishTitle)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Label(mystery.scriptureRef, systemImage: "book")
                            .font(.uiLabel)
                            .foregroundStyle(.goldLeaf)

                        Text("·")
                            .foregroundStyle(.goldLeaf)

                        Text("\(mystery.englishSetName)")
                            .font(.uiLabel)
                            .foregroundStyle(.sanctuaryRed)
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.3))
                    .frame(height: 1)

                // Meditation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meditation")
                        .font(.sectionHeader)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(mystery.meditationText)
                        .font(.englishBody)
                        .foregroundStyle(.ink)
                        .lineSpacing(6)
                }

                // Mystery number in set
                HStack {
                    Spacer()
                    Text("Mystery \(mystery.mysteryNumber) of 5")
                        .font(.uiCaption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
    }
}
