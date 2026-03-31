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

                // Tutorial link for beginners
                NavigationLink {
                    RosaryTutorialView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.goldLeaf)
                        Text("How to Pray the Rosary")
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                    }
                }
                .buttonStyle(.plain)

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
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(isSuggested ? Color.sanctuaryRed : Color.goldLeaf.opacity(0.2))
                    .frame(width: 3)
                    .padding(.trailing, 14)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(setType.latinName)
                            .font(.custom("Palatino", size: 16).weight(.medium))
                            .foregroundStyle(.ink)
                        if isSuggested {
                            Text("TODAY")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.sanctuaryRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    Text(setType.englishName)
                        .font(.custom("Palatino-Italic", size: 13))
                        .foregroundStyle(.goldLeaf)
                    Text("Traditional days: \(setType.traditionalDays)")
                        .font(.custom("Georgia", size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.goldLeaf.opacity(0.06)).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RosaryStartView(suggestedSet: .sorrowful)
    }
}
