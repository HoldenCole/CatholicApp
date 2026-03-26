import SwiftUI

struct PrayerMasteryRowView: View {
    let prayer: Prayer
    let comfortLevel: ComfortLevel
    let onComfortChange: (ComfortLevel) -> Void

    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Comfort icon
                Image(systemName: comfortLevel.sfSymbol)
                    .font(.system(size: 22))
                    .foregroundStyle(comfortColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(prayer.latinName)
                        .font(.latinBody)
                        .foregroundStyle(.ink)

                    Text(prayer.englishName)
                        .font(.englishCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Comfort badge
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingPicker.toggle()
                    }
                } label: {
                    Text(comfortLevel.label)
                        .font(.uiLabelSmall)
                        .foregroundStyle(comfortColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(comfortColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding()

            // Expandable comfort picker
            if showingPicker {
                comfortPicker
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Comfort Picker

    private var comfortPicker: some View {
        HStack(spacing: 8) {
            ForEach(ComfortLevel.allCases) { level in
                Button {
                    onComfortChange(level)
                    withAnimation(.spring(response: 0.3)) {
                        showingPicker = false
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: level.sfSymbol)
                            .font(.system(size: 18))

                        Text(level.label)
                            .font(.uiCaption)
                    }
                    .foregroundStyle(level == comfortLevel ? .white : comfortColorForLevel(level))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if level == comfortLevel {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(comfortColorForLevel(level))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(comfortColorForLevel(level).opacity(0.1))
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private var comfortColor: Color {
        comfortColorForLevel(comfortLevel)
    }

    private func comfortColorForLevel(_ level: ComfortLevel) -> Color {
        switch level {
        case .notStarted: return .comfortNotStarted
        case .learning: return .comfortLearning
        case .familiar: return .comfortFamiliar
        case .mastered: return .comfortMastered
        }
    }
}
