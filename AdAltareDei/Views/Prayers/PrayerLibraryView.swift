import SwiftUI
import SwiftData

struct PrayerLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PrayerLibraryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.groupedPrayers.enumerated()), id: \.offset) { index, group in
                        let (category, prayers) = group

                        if index > 0 {
                            ornamentalDivider
                        }

                        // Section header
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.latinName.uppercased())
                                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                                .foregroundStyle(.sanctuaryRed)
                                .tracking(3)
                            Text(category.displayName)
                                .font(.custom("Palatino-Italic", size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 10)

                        // Prayers
                        ForEach(prayers, id: \.id) { prayer in
                            NavigationLink {
                                PrayerDetailView(prayer: prayer)
                            } label: {
                                HStack(spacing: 14) {
                                    // Color-coded accent bar
                                    Rectangle()
                                        .fill(accentColor(for: category))
                                        .frame(width: 3, height: 36)
                                        .clipShape(RoundedRectangle(cornerRadius: 2))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prayer.latinName)
                                            .font(.custom("Palatino", size: 16).weight(.medium))
                                            .foregroundStyle(.ink)
                                        Text(prayer.englishName)
                                            .font(.custom("Georgia", size: 13))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color.goldLeaf.opacity(0.06))
                                        .frame(height: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Closing ornament
                    Text("✿ · ✿")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 12))
                        .foregroundStyle(.goldLeaf.opacity(0.4))
                        .tracking(8)
                        .padding(.vertical, 28)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(Color.parchment)
            .navigationTitle("Prayers")
            .searchable(text: $viewModel.searchText, prompt: "Search prayers...")
            .onAppear {
                viewModel.loadPrayers(context: modelContext)
            }
        }
    }

    private func accentColor(for category: PrayerCategory) -> Color {
        switch category {
        case .rosary: return .sanctuaryRed
        case .mass: return .goldLeaf
        case .devotional: return .comfortMastered
        case .litany: return .sanctuaryRed.opacity(0.6)
        }
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.3), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Text("✟")
                .font(.system(size: 11))
                .foregroundStyle(.goldLeaf.opacity(0.5))
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.3), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Spacer()
        }
        .padding(.vertical, 18)
    }
}

#Preview {
    PrayerLibraryView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
