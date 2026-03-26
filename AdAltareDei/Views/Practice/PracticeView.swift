import SwiftUI
import SwiftData

/// Practice view — full coaching loop (v1.4 will add recording).
/// Currently supports comfort rating and reference audio playback.
struct PracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel: PracticeViewModel
    @Environment(\.dismiss) private var dismiss

    init(prayer: Prayer) {
        _viewModel = StateObject(wrappedValue: PracticeViewModel(prayer: prayer))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppConstants.sectionSpacing) {
                // Prayer header
                VStack(spacing: 6) {
                    Text(viewModel.prayer.latinName)
                        .font(.latinTitle)
                        .foregroundStyle(.ink)

                    Text(viewModel.prayer.englishName)
                        .font(.englishCaption)
                        .foregroundStyle(.secondary)
                }

                // Reference audio
                if !viewModel.prayer.audioFileName.isEmpty {
                    AudioPlayerView(audioFileName: viewModel.prayer.audioFileName)
                }

                // Recording placeholder (v1.4)
                recordingSection

                // Comfort rating
                ComfortRatingView(selectedLevel: $viewModel.comfortRating)

                // Save button
                Button {
                    viewModel.saveSession(context: modelContext)
                    appSettings.recordPractice()
                    dismiss()
                } label: {
                    Text("Save Practice")
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
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recordingSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.circle")
                .font(.system(size: 56))
                .foregroundStyle(.sanctuaryRed.opacity(0.3))

            Text("Recording will be available in a future update")
                .font(.uiCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
    }
}
