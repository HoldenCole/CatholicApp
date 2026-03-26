import SwiftUI

struct MysteryCardView: View {
    let mystery: Mystery

    var body: some View {
        HStack(spacing: 14) {
            // Mystery number circle
            ZStack {
                Circle()
                    .fill(Color.sanctuaryRed.opacity(0.1))
                    .frame(width: 40, height: 40)

                Text("\(mystery.mysteryNumber)")
                    .font(.uiLabelLarge)
                    .foregroundStyle(.sanctuaryRed)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mystery.latinTitle)
                    .font(.latinBody)
                    .foregroundStyle(.ink)

                Text(mystery.englishTitle)
                    .font(.englishCaption)
                    .foregroundStyle(.secondary)

                Text(mystery.scriptureRef)
                    .font(.uiCaption)
                    .foregroundStyle(.goldLeaf)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
