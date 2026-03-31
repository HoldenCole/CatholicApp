import SwiftUI
import SwiftData

struct PrayerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel: PrayerDetailViewModel

    init(prayer: Prayer) {
        _viewModel = StateObject(wrappedValue: PrayerDetailViewModel(prayer: prayer))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                // Prayer header
                headerSection

                // Text mode toggle
                if viewModel.hasLatinText || viewModel.hasPhoneticText {
                    HStack {
                        Spacer()
                        TextModeToggle(
                            selectedMode: $viewModel.textMode,
                            hasLatin: viewModel.hasLatinText,
                            hasPhonetic: viewModel.hasPhoneticText
                        )
                        Spacer()
                    }
                }

                // Divider
                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.3))
                    .frame(height: 1)

                // Prayer text
                prayerTextSection

                // Audio player placeholder (for v1.3)
                if viewModel.textMode != .english && !viewModel.prayer.audioFileName.isEmpty {
                    AudioPlayerView(audioFileName: viewModel.prayer.audioFileName)
                }

                // Comfort level badge
                if let session = viewModel.latestSession {
                    comfortBadge(session.comfortRating)
                }

                // Practice button
                NavigationLink {
                    PracticeView(prayer: viewModel.prayer)
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Practice This Prayer")
                    }
                    .font(.uiLabelLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.sanctuaryRed)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.textMode = appSettings.defaultTextMode
            viewModel.loadLatestSession(context: modelContext)
        }
    }

    // MARK: - Header (Dark with Marian symbol)

    private var headerSection: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.prayer.latinName)
                    .font(.custom("Palatino", size: 26).weight(.bold))
                    .foregroundStyle(.white)

                Text(viewModel.prayer.englishName)
                    .font(.custom("Palatino-Italic", size: 16))
                    .foregroundStyle(.goldLeaf)

                Text(viewModel.prayer.category.latinName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.goldLeaf)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.goldLeaf.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.top, 4)
            }

            // Marian monogram
            VStack(spacing: 0) {
                Text("M")
                    .font(.custom("Palatino", size: 36).weight(.light))
                    .foregroundStyle(.goldLeaf.opacity(0.15))
                Text("✦")
                    .font(.system(size: 10))
                    .foregroundStyle(.goldLeaf.opacity(0.15))
                    .offset(y: -6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                startPoint: .top, endPoint: .bottom
            )
        )
        .padding(.horizontal, -16)
        .padding(.top, -16)
    }

    // MARK: - Prayer Text

    @ViewBuilder
    private var prayerTextSection: some View {
        switch viewModel.textMode {
        case .missal:
            if viewModel.hasLatinText {
                MissalTextView(
                    latinText: viewModel.prayer.latinText,
                    englishText: viewModel.prayer.englishText
                )
            }

        case .english:
            Text(viewModel.prayer.englishText)
                .font(.englishBody)
                .foregroundStyle(.ink)
                .lineSpacing(6)

        case .latin:
            Text(viewModel.prayer.latinText)
                .font(.latinBody)
                .foregroundStyle(.ink)
                .lineSpacing(6)

        case .phonetic:
            if viewModel.hasPhoneticText {
                PhoneticTextView(phoneticText: viewModel.prayer.phoneticText)
            }
        }
    }

    // MARK: - Comfort Badge

    private func comfortBadge(_ level: ComfortLevel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: level.sfSymbol)
                .foregroundStyle(comfortColor(level))

            Text(level.label)
                .font(.uiLabel)
                .foregroundStyle(.secondary)

            Spacer()

            Text(level.latinLabel)
                .font(.latinCaption)
                .foregroundStyle(.goldLeaf)
        }
        .padding(.vertical, 12)
    }

    private func comfortColor(_ level: ComfortLevel) -> Color {
        switch level {
        case .notStarted: return .comfortNotStarted
        case .learning: return .comfortLearning
        case .familiar: return .comfortFamiliar
        case .mastered: return .comfortMastered
        }
    }
}
