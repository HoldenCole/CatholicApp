import SwiftUI

struct MissalView: View {
    @StateObject private var viewModel = MissalViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ordo Missæ")
                            .font(.latinDisplay)
                            .foregroundStyle(.ink)

                        Text("Ordinary of the Traditional Latin Mass")
                            .font(.englishCaption)
                            .foregroundStyle(.secondary)

                        Text("1962 Missale Romanum")
                            .font(.uiCaption)
                            .foregroundStyle(.goldLeaf)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.goldLeaf.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)

                    // Mass sections grouped by part
                    ForEach(viewModel.groupedSections, id: \.0) { part, sections in
                        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
                            SectionHeaderView(
                                title: part.latinName,
                                subtitle: part.displayName
                            )
                            .padding(.horizontal)

                            ForEach(sections) { section in
                                NavigationLink {
                                    MissalSectionDetailView(section: section)
                                } label: {
                                    MissalSectionRow(section: section)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.parchment)
            .navigationTitle("Missal")
            .onAppear {
                viewModel.loadSections()
            }
        }
    }
}

struct MissalSectionRow: View {
    let section: MissalSection

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(section.isProper ? Color.goldLeaf.opacity(0.12) : Color.sanctuaryRed.opacity(0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: section.isProper ? "calendar" : "book.closed")
                    .font(.system(size: 18))
                    .foregroundStyle(section.isProper ? .goldLeaf : .sanctuaryRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(section.latinTitle)
                    .font(.latinBody)
                    .foregroundStyle(.ink)

                HStack(spacing: 6) {
                    Text(section.title)
                        .font(.englishCaption)
                        .foregroundStyle(.secondary)

                    if let posture = section.posture {
                        Text("·")
                            .font(.englishCaption)
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                        Text(posture.capitalized)
                            .font(.uiCaption)
                            .foregroundStyle(.goldLeaf)
                    }
                }
            }

            Spacer()

            if section.isProper {
                Text("Proper")
                    .font(.uiCaption)
                    .foregroundStyle(.goldLeaf)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.goldLeaf.opacity(0.1))
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
}

#Preview {
    MissalView()
}
