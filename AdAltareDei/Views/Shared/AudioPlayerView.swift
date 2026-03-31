import SwiftUI

/// Placeholder audio player view.
struct AudioPlayerView: View {
    let audioFileName: String
    @State private var isPlaying = false
    @State private var barHeights: [CGFloat] = (0..<40).map { _ in CGFloat.random(in: 8...50) }

    var body: some View {
        VStack(spacing: 10) {
            // Waveform
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.goldLeaf.opacity(0.08))
                .frame(height: 50)
                .overlay {
                    HStack(spacing: 2) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { _, height in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.goldLeaf.opacity(isPlaying ? 0.7 : 0.3))
                                .frame(width: 3, height: height * 0.8)
                        }
                    }
                    .padding(.horizontal, 8)
                }

            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPlaying.toggle()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.goldLeaf)
                }

                Spacer()

                Text("Reference Recording")
                    .font(.custom("Palatino-Italic", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
