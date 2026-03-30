import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = ProgressViewModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                    // Mastery ring
                    MasteryRingView(percentage: viewModel.masteryPercentage)
                        .frame(maxWidth: .infinity)

                    // Streak
                    StreakView(streak: appSettings.currentStreak)

                    // Stats summary
                    statsSection

                    // Prayer mastery list
                    prayerListSection
                }
                .padding()
            }
            .background(Color.parchment)
            .navigationTitle("Progress")
            .onAppear {
                viewModel.loadData(context: modelContext)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(count: viewModel.masteredCount, label: "Mastered", color: .comfortMastered)
            statCard(count: viewModel.familiarCount, label: "Familiar", color: .comfortFamiliar)
            statCard(count: viewModel.learningCount, label: "Learning", color: .comfortLearning)
        }
    }

    private func statCard(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.englishDisplay)
                .foregroundStyle(color)

            Text(label)
                .font(.uiCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Prayer List

    private var prayerListSection: some View {
        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
            SectionHeaderView(title: "All Prayers", subtitle: "Omnes Orationes")

            ForEach(viewModel.prayers, id: \.id) { prayer in
                PrayerMasteryRowView(
                    prayer: prayer,
                    comfortLevel: viewModel.comfortLevel(for: prayer)
                ) { newLevel in
                    viewModel.updateComfortLevel(for: prayer, to: newLevel, context: modelContext)
                    appSettings.recordPractice()
                }
            }
        }
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
