import SwiftUI

struct MissalSectionDetailView: View {
    let section: MissalSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.latinTitle)
                        .font(.latinDisplay)
                        .foregroundStyle(.ink)

                    Text(section.title)
                        .font(.englishTitle)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Text(section.part.latinName)
                            .font(.uiCaption)
                            .foregroundStyle(.sanctuaryRed)

                        if section.isProper {
                            Text("·")
                                .foregroundStyle(.goldLeaf)
                            Text("Proper")
                                .font(.uiCaption)
                                .foregroundStyle(.goldLeaf)
                        }
                    }
                }

                // Rubric
                if !section.rubric.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hand.point.right")
                            .foregroundStyle(.sanctuaryRed)
                            .font(.system(size: 14))

                        Text(section.rubric)
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundStyle(.sanctuaryRed.opacity(0.8))
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color.sanctuaryRed.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Side-by-side missal text
                MissalTextView(
                    latinText: section.latinText,
                    englishText: section.englishText
                )
            }
            .padding()
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
    }
}
