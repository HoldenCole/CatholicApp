import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = ProgressViewModel()
    @State private var showingSettings = false

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.goldLeaf)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
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

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Default Text Mode") {
                    Picker("Text Mode", selection: $appSettings.defaultTextMode) {
                        ForEach(TextMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Ad Altare Dei")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.2")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Rite")
                        Spacer()
                        Text("Traditional Latin Mass (1962)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("All data is stored locally on your device. No analytics, no accounts, no ads.")
                        .font(.uiCaption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Privacy")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.sanctuaryRed)
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
