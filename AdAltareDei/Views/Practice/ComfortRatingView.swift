import SwiftUI

struct ComfortRatingView: View {
    @Binding var selectedLevel: ComfortLevel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ComfortLevel.allCases) { level in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedLevel = level
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(level.label)
                            .font(.custom("Palatino", size: 12))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selectedLevel == level ? .white : colorForLevel(level))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedLevel == level
                        ? colorForLevel(level)
                        : colorForLevel(level).opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                selectedLevel == level ? Color.clear : colorForLevel(level).opacity(0.2),
                                lineWidth: 1
                            )
                    )
                }
            }
        }
    }

    private func colorForLevel(_ level: ComfortLevel) -> Color {
        switch level {
        case .notStarted: return .secondary
        case .learning: return .sanctuaryRed
        case .familiar: return .goldLeaf
        case .mastered: return .comfortMastered
        }
    }
}
