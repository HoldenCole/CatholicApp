import SwiftUI

// A tappable flashcard that shows Latin on the front and
// English + phonetic on the back. Tap to flip.

struct FlashCard: View {
    let card: Course.Section.Card
    @State private var isFlipped = false

    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.3)) { isFlipped.toggle() } } label: {
            VStack(alignment: .center, spacing: 6) {
                if isFlipped {
                    // Back: English + phonetic
                    if let eng = card.eng {
                        Text(eng)
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                    }
                    if let phon = card.phon, !phon.isEmpty {
                        Text("[\(phon)]")
                            .font(.captionSm)
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Text("tap to see Latin")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                        .padding(.top, 4)
                } else {
                    // Front: Latin
                    Text(card.lat ?? "")
                        .font(.titleL)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text("tap to reveal")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(isFlipped ? Color.goldLeaf.opacity(0.06) : Color.pageBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isFlipped ? Color.goldLeaf.opacity(0.4) : Color.frameLine, lineWidth: 0.5)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
