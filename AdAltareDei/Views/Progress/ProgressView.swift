import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header with mastery ring and stats
                    VStack(spacing: 12) {
                        MasteryRingView(percentage: viewModel.masteryPercentage)

                        HStack(spacing: 0) {
                            statItem(count: viewModel.masteredCount, label: "Mastered", color: .comfortMastered)
                            statItem(count: viewModel.familiarCount, label: "Familiar", color: .comfortFamiliar)
                            statItem(count: viewModel.learningCount, label: "Learning", color: .comfortLearning)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    // Content on parchment
                    VStack(alignment: .leading, spacing: 0) {
                        // Streak
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(Color.sanctuaryRed)
                                .frame(width: 3)
                                .padding(.trailing, 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(appSettings.currentStreak)-Day Streak")
                                    .font(.custom("Palatino", size: 17).weight(.semibold))
                                    .foregroundStyle(.ink)
                                Text("Keep practicing daily.")
                                    .font(.custom("Georgia", size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 16)

                        ornamentalDivider

                        // Prayer list header
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ALL PRAYERS")
                                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                                .foregroundStyle(.sanctuaryRed)
                                .tracking(3)
                            Text("Omnes Orationes")
                                .font(.custom("Palatino-Italic", size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 12)

                        // Prayer mastery list with progress bars
                        ForEach(viewModel.prayers, id: \.id) { prayer in
                            let level = viewModel.comfortLevel(for: prayer)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(prayer.latinName)
                                        .font(.custom("Palatino", size: 16))
                                        .foregroundStyle(.ink)
                                    Spacer()
                                    Text(level.label)
                                        .font(.custom("Palatino-Italic", size: 12))
                                        .foregroundStyle(comfortColor(level))
                                }
                                Text(prayer.englishName)
                                    .font(.custom("Palatino-Italic", size: 12))
                                    .foregroundStyle(.goldLeaf)

                                // Mini progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.goldLeaf.opacity(0.08))
                                            .frame(height: 3)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(comfortColor(level))
                                            .frame(width: geo.size.width * progressWidth(level), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.goldLeaf.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }

                        Text("✿ · ✿")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12))
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                            .tracking(8)
                            .padding(.vertical, 28)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .background(Color.parchment)
            .navigationTitle("Progress")
            .onAppear {
                viewModel.loadData(context: modelContext)
            }
        }
    }

    private func statItem(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.custom("Palatino", size: 20).weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.custom("Palatino-Italic", size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func comfortColor(_ level: ComfortLevel) -> Color {
        switch level {
        case .notStarted: return .secondary.opacity(0.3)
        case .learning: return .sanctuaryRed
        case .familiar: return .goldLeaf
        case .mastered: return .comfortMastered
        }
    }

    private func progressWidth(_ level: ComfortLevel) -> Double {
        switch level {
        case .notStarted: return 0
        case .learning: return 0.33
        case .familiar: return 0.66
        case .mastered: return 1.0
        }
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle().frame(height: 1).foregroundStyle(.clear)
                .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
            Text("✟").font(.system(size: 11)).foregroundStyle(.goldLeaf.opacity(0.5))
            Rectangle().frame(height: 1).foregroundStyle(.clear)
                .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
            Spacer()
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    ProgressTabView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
