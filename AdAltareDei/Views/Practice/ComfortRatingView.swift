import SwiftUI

struct ComfortRatingView: View {
    @Binding var selectedLevel: ComfortLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How comfortable are you?")
                .font(.uiLabel)
                .foregroundStyle(.ink)

            HStack(spacing: 8) {
                ForEach(ComfortLevel.allCases) { level in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedLevel = level
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: level.sfSymbol)
                                .font(.system(size: 20))

                            Text(level.label)
                                .font(.uiCaption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selectedLevel == level ? .white : colorForLevel(level))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedLevel == level
                                      ? colorForLevel(level)
                                      : colorForLevel(level).opacity(0.1))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
    }

    private func colorForLevel(_ level: ComfortLevel) -> Color {
        switch level {
        case .notStarted: return .comfortNotStarted
        case .learning: return .comfortLearning
        case .familiar: return .comfortFamiliar
        case .mastered: return .comfortMastered
        }
    }
}

#Preview {
    ComfortRatingView(selectedLevel: .constant(.familiar))
        .padding()
        .background(Color.parchment)
}
