import SwiftUI
import SwiftData

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
            VStack(alignment: .leading, spacing: 0) {
                // Dark header
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.prayer.latinName)
                        .font(.custom("Palatino", size: 24).weight(.bold))
                        .foregroundStyle(.white)
                    Text(viewModel.prayer.englishName)
                        .font(.custom("Palatino-Italic", size: 14))
                        .foregroundStyle(.goldLeaf)
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

                VStack(alignment: .leading, spacing: 0) {
                    // Audio placeholder
                    if !viewModel.prayer.audioFileName.isEmpty {
                        AudioPlayerView(audioFileName: viewModel.prayer.audioFileName)
                            .padding(.vertical, 16)
                    }

                    ornamentalDivider

                    // Comfort rating
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOW COMFORTABLE ARE YOU?")
                            .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .tracking(3)
                    }
                    .padding(.bottom, 12)

                    ComfortRatingView(selectedLevel: $viewModel.comfortRating)

                    ornamentalDivider

                    // Save button
                    Button {
                        viewModel.saveSession(context: modelContext)
                        appSettings.recordPractice()
                        dismiss()
                    } label: {
                        Text("Save Practice")
                            .font(.custom("Palatino", size: 16).weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.sanctuaryRed)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle().frame(height: 1).foregroundStyle(.clear)
                .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
            Spacer()
        }
        .padding(.vertical, 16)
    }
}
