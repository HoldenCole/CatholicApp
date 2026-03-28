import SwiftUI

/// Placeholder audio player view for v1.3.
/// Will integrate DSWaveformImage and AVFoundation playback.
struct AudioPlayerView: View {
    let audioFileName: String
    @State private var isPlaying = false
    @State private var barHeights: [CGFloat] = (0..<40).map { _ in CGFloat.random(in: 8...50) }

    var body: some View {
        VStack(spacing: 12) {
            // Waveform placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.goldLeaf.opacity(0.15))
                .frame(height: 60)
                .overlay {
                    // Simulated waveform bars
                    HStack(spacing: 2) {
                        ForEach(Array(barHeights.enumerated()), id: \.offset) { _, height in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.goldLeaf.opacity(isPlaying ? 0.8 : 0.4))
                                .frame(width: 3, height: height)
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
                        .font(.system(size: 36))
                        .foregroundStyle(.goldLeaf)
                }

                Spacer()

                Text("Reference Recording")
                    .font(.uiCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
    }
}
