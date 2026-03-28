import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = TodayViewModel()
    @State private var todaysDevotions: [TraditionalDevotion] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                    // Header with date and Latin feria
                    headerSection

                    // Pray the Rosary card
                    rosaryLauncherCard

                    // Today's Devotions
                    if !todaysDevotions.isEmpty {
                        devotionsSection
                    }

                    // Today's Mystery Set
                    mysterySetSection

                    // Saturday note if applicable
                    if viewModel.isSaturday {
                        saturdayNoteView
                    }
                }
                .padding()
            }
            .background(Color.parchment)
            .navigationTitle("Today")
            .onAppear {
                viewModel.loadMysteries(context: modelContext)
                loadDevotions()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
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

                Spacer()

                // Missal rite badge
                Text(appSettings.missalRite.displayName)
                    .font(.uiCaption)
                    .foregroundStyle(.goldLeaf)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.goldLeaf.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Rosary Launcher

    private var rosaryLauncherCard: some View {
        NavigationLink {
            RosaryStartView(suggestedSet: MysteryScheduleService.todaysPrimarySet())
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.sanctuaryRed.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: "rosette")
                        .font(.system(size: 24))
                        .foregroundStyle(.sanctuaryRed)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Pray the Rosary")
                        .font(.uiLabelLarge)
                        .foregroundStyle(.ink)

                    Text("\(MysteryScheduleService.todaysPrimarySet().latinName) — \(MysteryScheduleService.todaysPrimarySet().englishName)")
                        .font(.uiCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.sanctuaryRed)
            }
            .padding()
            .background(Color.warmWhite)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Devotions Section

    private var devotionsSection: some View {
        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
            SectionHeaderView(
                title: "Today's Devotions",
                subtitle: "Devotiones Hodiernae"
            )

            ForEach(todaysDevotions) { devotion in
                devotionCard(devotion)
            }
        }
    }

    private func devotionCard(_ devotion: TraditionalDevotion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(devotion.isFasting || devotion.isAbstinence
                          ? Color.sanctuaryRed.opacity(0.08)
                          : Color.goldLeaf.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: devotion.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(devotion.isFasting || devotion.isAbstinence
                                    ? .sanctuaryRed : .goldLeaf)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(devotion.title)
                        .font(.uiLabel)
                        .foregroundStyle(.ink)

                    if devotion.isAbstinence {
                        Text("Abstinence")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sanctuaryRed.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if devotion.isFasting {
                        Text("Fast")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.sanctuaryRed.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Text(devotion.description)
                    .font(.uiCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                if let note = devotion.seasonalNote {
                    Text(note)
                        .font(.uiCaption)
                        .foregroundStyle(.goldLeaf)
                }
            }
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 6, y: 1)
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

    // MARK: - Load Devotions

    private func loadDevotions() {
        guard let url = Bundle.main.url(forResource: "devotions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let allDevotions = try? JSONDecoder().decode([TraditionalDevotion].self, from: data) else {
            return
        }

        let weekday = Calendar.current.component(.weekday, from: Date())
        todaysDevotions = allDevotions.filter { devotion in
            // Show if applicable today (by weekday) or daily devotions
            if let days = devotion.applicableDays {
                return days.contains(weekday)
            }
            // Show daily devotions
            return devotion.category == .dailyDevotion
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
