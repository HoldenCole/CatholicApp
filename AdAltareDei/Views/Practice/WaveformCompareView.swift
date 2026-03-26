import SwiftUI

/// Stacked waveform comparison view for v1.4.
/// Shows reference waveform (Gold Leaf) and user recording (steel blue) side by side.
struct WaveformCompareView: View {
    let referenceFileName: String
    let userRecordingFileName: String?

    var body: some View {
        VStack(spacing: 8) {
            // Reference waveform
            VStack(alignment: .leading, spacing: 4) {
                Text("Reference")
                    .font(.uiCaption)
                    .foregroundStyle(.goldLeaf)

                waveformPlaceholder(color: .goldLeaf)
            }

            Rectangle()
                .fill(Color.goldLeaf.opacity(0.3))
                .frame(height: 1)

            // User waveform
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Recording")
                    .font(.uiCaption)
                    .foregroundStyle(.blue)

                if userRecordingFileName != nil {
                    waveformPlaceholder(color: .blue)
                } else {
                    Text("Record yourself to compare")
                        .font(.uiCaption)
                        .foregroundStyle(.secondary)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
    }

    private func waveformPlaceholder(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color.opacity(0.1))
            .frame(height: 50)
            .overlay {
                HStack(spacing: 2) {
                    ForEach(0..<35, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.opacity(0.4))
                            .frame(width: 3, height: CGFloat.random(in: 6...40))
                    }
                }
            }
    }
}

#Preview {
    WaveformCompareView(referenceFileName: "ave_maria_ref.m4a", userRecordingFileName: nil)
        .padding()
        .background(Color.parchment)
}
