import SwiftUI
import SwiftData

struct PrayerLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PrayerLibraryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                    ForEach(viewModel.groupedPrayers, id: \.0) { category, prayers in
                        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
                            SectionHeaderView(
                                title: category.displayName,
                                subtitle: category.latinName
                            )
                            .padding(.horizontal)

                            ForEach(prayers, id: \.id) { prayer in
                                NavigationLink {
                                    PrayerDetailView(prayer: prayer)
                                } label: {
                                    PrayerRowView(prayer: prayer)
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
            .navigationTitle("Prayers")
            .searchable(text: $viewModel.searchText, prompt: "Search prayers...")
            .onAppear {
                viewModel.loadPrayers(context: modelContext)
            }
        }
    }
}

// MARK: - Prayer Row

struct PrayerRowView: View {
    let prayer: Prayer

    var body: some View {
        HStack(spacing: 14) {
            // Prayer icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.sanctuaryRed.opacity(0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: "text.book.closed")
                    .font(.system(size: 18))
                    .foregroundStyle(.sanctuaryRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(prayer.latinName)
                    .font(.latinBody)
                    .foregroundStyle(.ink)

                Text(prayer.englishName)
                    .font(.englishCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Show indicators for available content
            HStack(spacing: 6) {
                if !prayer.latinText.isEmpty {
                    contentBadge("L")
                }
                if !prayer.phoneticText.isEmpty {
                    contentBadge("P")
                }
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

    private func contentBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.goldLeaf)
            .frame(width: 20, height: 20)
            .background(Color.goldLeaf.opacity(0.12))
            .clipShape(Circle())
    }
}

#Preview {
    PrayerLibraryView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
