import SwiftUI

/// Detail view for a devotion tapped from the Today tab.
/// Shows full description and links to the Reference section for deeper reading.
struct DevotionDetailView: View {
    let devotion: TraditionalDevotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(devotion.title)
                        .font(.custom("Palatino", size: 28).weight(.bold))
                        .foregroundStyle(.ink)

                    Text(devotion.latinTitle)
                        .font(.custom("Palatino-Italic", size: 16))
                        .foregroundStyle(.goldLeaf)

                    // Tags
                    HStack(spacing: 8) {
                        if devotion.isAbstinence {
                            tagView("Abstinence")
                        }
                        if devotion.isFasting {
                            tagView("Fast")
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 16)

                ornamentalDivider

                // Full description
                Text(devotion.description)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(.ink)
                    .lineSpacing(6)
                    .padding(.vertical, 16)

                // Seasonal note if applicable
                if let note = devotion.seasonalNote {
                    ornamentalDivider

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTE")
                            .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .tracking(3)

                        Text(note)
                            .font(.custom("Georgia-Italic", size: 15))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 16)
                }

                // Closing ornament
                Text("✿ · ✿")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 12))
                    .foregroundStyle(.goldLeaf.opacity(0.4))
                    .tracking(8)
                    .padding(.vertical, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tagView(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.sanctuaryRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1)
            )
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Spacer()
        }
    }
}
