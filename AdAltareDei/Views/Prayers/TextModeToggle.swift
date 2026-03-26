import SwiftUI

struct TextModeToggle: View {
    @Binding var selectedMode: TextMode
    var hasLatin: Bool = true
    var hasPhonetic: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TextMode.allCases) { mode in
                let isDisabled = (mode == .latin && !hasLatin) ||
                                 (mode == .phonetic && !hasPhonetic)
                let isSelected = selectedMode == mode

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.uiLabelSmall)
                        .foregroundStyle(isSelected ? .white : .ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.sanctuaryRed)
                            }
                        }
                }
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.35 : 1.0)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.ink.opacity(0.06))
        )
    }
}

#Preview {
    TextModeToggle(selectedMode: .constant(.english))
        .padding()
}
