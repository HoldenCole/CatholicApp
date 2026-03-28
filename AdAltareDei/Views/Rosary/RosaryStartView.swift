import SwiftUI

/// Screen to choose which mystery set to pray before starting the guided Rosary.
struct RosaryStartView: View {
    let suggestedSet: MysterySetType
    @State private var selectedSet: MysterySetType?

    var body: some View {
        ScrollView {
            VStack(spacing: AppConstants.sectionSpacing) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "rosette")
                        .font(.system(size: 40))
                        .foregroundStyle(.sanctuaryRed)

                    Text("Sacratissimum Rosarium")
                        .font(.latinTitle)
                        .foregroundStyle(.ink)

                    Text("The Most Holy Rosary")
                        .font(.englishCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Suggested
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Mysteries")
                        .font(.sectionHeader)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                        .textCase(.uppercase)

                    mysterySetCard(suggestedSet, isSuggested: true)
                }

                // All options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or Choose")
                        .font(.sectionHeader)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                        .textCase(.uppercase)

                    ForEach(MysterySetType.allCases.filter { $0 != suggestedSet }) { setType in
                        mysterySetCard(setType, isSuggested: false)
                    }
                }
            }
            .padding()
        }
        .background(Color.parchment)
        .navigationTitle("Rosary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mysterySetCard(_ setType: MysterySetType, isSuggested: Bool) -> some View {
        NavigationLink {
            RosaryFlowView(mysterySetType: setType)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSuggested ? Color.sanctuaryRed.opacity(0.1) : Color.goldLeaf.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "rosette")
                        .font(.system(size: 20))
                        .foregroundStyle(isSuggested ? .sanctuaryRed : .goldLeaf)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(setType.latinName)
                        .font(.latinBody)
                        .foregroundStyle(.ink)

                    Text(setType.englishName)
                        .font(.englishCaption)
                        .foregroundStyle(.secondary)

                    Text("Traditional days: \(setType.traditionalDays)")
                        .font(.uiCaption)
                        .foregroundStyle(.goldLeaf)
                }

                Spacer()

                if isSuggested {
                    Text("Today")
                        .font(.uiCaption)
                        .foregroundStyle(.sanctuaryRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.sanctuaryRed.opacity(0.1))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.warmWhite)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RosaryStartView(suggestedSet: .sorrowful)
    }
}
