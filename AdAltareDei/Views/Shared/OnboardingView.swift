import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "cross.fill",
            title: "Ad Altare Dei",
            subtitle: "To the Altar of God",
            description: "Learn to pray the traditional Catholic prayers in beautiful Ecclesiastical Latin — the language of the Church for nearly two millennia.",
            accentColor: .sanctuaryRed
        ),
        OnboardingPage(
            icon: "text.book.closed.fill",
            title: "Read, Listen, Practice",
            subtitle: "Lege, Audi, Exerce",
            description: "Each prayer is available in English, Latin, and a phonetic guide with stressed syllables highlighted. Listen to reference recordings and practice at your own pace.",
            accentColor: .goldLeaf
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            title: "Track Your Progress",
            subtitle: "Progressus Tuus",
            description: "Rate your comfort level with each prayer and watch your mastery grow. Build a daily practice streak as you deepen your knowledge of sacred Latin.",
            accentColor: .sanctuaryRed
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    onboardingPageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom section
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.sanctuaryRed : Color.goldLeaf.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                // Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        appSettings.hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Begin Praying")
                        .font(.uiLabelLarge)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.sanctuaryRed)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Skip button
                if currentPage < pages.count - 1 {
                    Button {
                        appSettings.hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.uiLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color.parchment)
    }

    private func onboardingPageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(page.accentColor)
            }

            // Title
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.latinDisplay)
                    .foregroundStyle(.ink)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.latinCaption)
                    .foregroundStyle(.goldLeaf)
                    .tracking(1.5)
                    .textCase(.uppercase)
            }

            // Description
            Text(page.description)
                .font(.englishBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let accentColor: Color
}

#Preview {
    OnboardingView()
        .environmentObject(AppSettings())
}
