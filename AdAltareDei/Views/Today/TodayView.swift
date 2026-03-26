import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                    // Header with date and Latin feria
                    headerSection

                    // Today's Mystery Set
                    mysterySetSection

                    // Saturday note if applicable
                    if viewModel.isSaturday {
                        saturdayNoteView
                    }

                    // Quick prayer links
                    quickPrayersSection
                }
                .padding()
            }
            .background(Color.parchment)
            .navigationTitle("Today")
            .onAppear {
                viewModel.loadMysteries(context: modelContext)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.latinFeria)
                .font(.latinCaption)
                .foregroundStyle(.goldLeaf)
                .tracking(1.5)
                .textCase(.uppercase)

            Text(viewModel.englishDay)
                .font(.englishDisplay)
                .foregroundStyle(.ink)

            Text(viewModel.dateString)
                .font(.englishCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }

    // MARK: - Mystery Set

    private var mysterySetSection: some View {
        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
            ForEach(viewModel.todaysSetTypes) { setType in
                VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
                    SectionHeaderView(
                        title: setType.latinName,
                        subtitle: setType.englishName
                    )

                    let mysteries = viewModel.todaysMysteries.filter { $0.setType == setType }
                    ForEach(mysteries, id: \.id) { mystery in
                        NavigationLink {
                            MysteryDetailView(mystery: mystery)
                        } label: {
                            MysteryCardView(mystery: mystery)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Saturday Note

    private var saturdayNoteView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.goldLeaf)
                .font(.system(size: 16))

            Text(MysteryScheduleService.saturdayNote)
                .font(.uiCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.goldLeaf.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Prayers

    private var quickPrayersSection: some View {
        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
            SectionHeaderView(title: "Rosary Prayers", subtitle: "Orationes Rosarii")

            Text("Open the Prayers tab to browse all prayers with Latin text, phonetic guides, and reference recordings.")
                .font(.englishCaption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
