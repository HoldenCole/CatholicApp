import SwiftUI

// A tappable flashcard that shows Latin on the front and
// English + phonetic on the back. Tap to flip.

struct FlashCard: View {
    let card: Course.Section.Card
    @State private var isFlipped = false
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some View {
        Button { withAnimation(.easeInOut(duration: 0.3)) { isFlipped.toggle() } } label: {
            VStack(alignment: .center, spacing: 6) {
                if isFlipped {
                    // Back: English + phonetic
                    if let eng = card.eng {
                        Text(eng)
                            .appFont(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                    }
                    if let phon = card.phon, !phon.isEmpty {
                        Text("[\(phon)]")
                            .appFont(.captionSm)
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Text(ContentStore.shared.uiString("learn.flash.tap_latin", "tap to see Latin"))
                        .appFont(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                        .padding(.top, 4)
                } else {
                    // Front: Latin
                    Text(card.lat ?? "")
                        .appFont(.titleL)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(ContentStore.shared.uiString("learn.flash.tap_reveal", "tap to reveal"))
                        .appFont(.captionSm)
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
