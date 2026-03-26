import SwiftUI

struct StreakView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.sanctuaryRed.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(streak > 0 ? .sanctuaryRed : .gray.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(streak > 0 ? "\(streak)-Day Streak" : "No Streak Yet")
                    .font(.uiLabelLarge)
                    .foregroundStyle(.ink)

                Text(streak > 0
                     ? "Keep practicing daily to maintain your streak!"
                     : "Rate your comfort on any prayer to start a streak.")
                    .font(.uiCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakView(streak: 7)
        StreakView(streak: 0)
    }
    .padding()
    .background(Color.parchment)
}
