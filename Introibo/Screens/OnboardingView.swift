import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .cornerRadius(18)
                        .shadow(color: Color.sanctuaryRed.opacity(0.3), radius: 12)

                    // Title
                    VStack(spacing: 8) {
                        Text("Introíbo")
                            .font(.system(size: 40, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Text("Ad altáre Dei")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                            .textCase(.uppercase)
                            .tracking(3)
                    }

                    // Feature list
                    VStack(alignment: .leading, spacing: 18) {
                        featureRow(icon: "sun.horizon", title: "Liturgical Today", desc: "Daily psalm, penance, liturgical season, and feast days at a glance.")
                        featureRow(icon: "book.closed", title: "1962 Missal", desc: "The complete Ordinary of the Traditional Latin Mass with side-by-side translation.")
                        featureRow(icon: "book.pages", title: "22 Prayers", desc: "Full Latin and English for every essential Catholic prayer.")
                        featureRow(icon: "cross", title: "Rosary & Stations", desc: "Interactive bead-by-bead Rosary and the 14 Stations of the Cross with meditations.")
                        featureRow(icon: "clock", title: "Divine Office", desc: "All 8 canonical hours of the 1962 Roman Breviary.")
                        featureRow(icon: "person.fill", title: "Follow a Saint", desc: "Choose a patron and follow their daily practices with streak tracking.")
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)

                    // Principles
                    VStack(spacing: 6) {
                        Text("Free forever. No accounts. No tracking. No ads.")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.tertiaryText)
                        Text("All data stored locally on your device.")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .padding(.top, 16)

                    Spacer(minLength: 20)
                }
            }

            // Begin button
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Introíbo ad altáre Dei  ✠")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ivory)
                    .tracking(2)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.sanctuaryRed)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.sanctuaryRed)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(desc)
                    .font(.captionSm)
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(2)
            }
        }
    }
}
