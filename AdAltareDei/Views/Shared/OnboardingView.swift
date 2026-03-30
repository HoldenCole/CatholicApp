import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            missalSelectionPage.tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)
        .ignoresSafeArea()
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Cross symbol
            Text("✟")
                .font(.system(size: 56))
                .foregroundStyle(.goldLeaf.opacity(0.7))
                .padding(.bottom, 12)

            // App name
            Text("Ad Altare Dei")
                .font(.custom("Palatino", size: 34).weight(.bold))
                .foregroundStyle(.white)

            Text("To the Altar of God")
                .font(.custom("Palatino-Italic", size: 16))
                .foregroundStyle(.goldLeaf)
                .tracking(2)
                .padding(.top, 4)

            Text("Learn to pray the traditional Catholic prayers in the sacred language of the Church.")
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.top, 20)

            Spacer()

            // Feature list
            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "book.pages", text: "Side-by-side Latin and English like a hand missal")
                featureRow(icon: "textformat.abc", text: "Phonetic guides with stressed syllables highlighted")
                featureRow(icon: "cross", text: "Full Ordinary of the Traditional Latin Mass")
                featureRow(icon: "rosette", text: "Guided Rosary with bead-by-bead progress")
                featureRow(icon: "sparkles", text: "And much more to come")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Bottom
            VStack(spacing: 16) {
                Button {
                    withAnimation { currentPage = 1 }
                } label: {
                    Text("Begin →")
                        .font(.custom("Palatino", size: 16).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.sanctuaryRed)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Page dots
                HStack(spacing: 8) {
                    Circle().fill(Color.sanctuaryRed).frame(width: 8, height: 8).scaleEffect(1.2)
                    Circle().fill(Color.goldLeaf.opacity(0.3)).frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "1C1410"), Color(hex: "1a1410")],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.goldLeaf)
                .frame(width: 28, alignment: .center)
            Text(text)
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Page 2: Missal Selection

    private var missalSelectionPage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("CHOOSE YOUR MISSAL")
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.goldLeaf)
                .tracking(3)
                .padding(.bottom, 8)

            Text("Which calendar does\nyour community follow?")
                .font(.custom("Palatino", size: 24).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 10) {
                ForEach(MissalRite.allCases) { rite in
                    Button {
                        appSettings.missalRite = rite
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rite.displayName)
                                    .font(.custom("Palatino", size: 17).weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(rite.latinName)
                                    .font(.custom("Palatino-Italic", size: 12))
                                    .foregroundStyle(.goldLeaf)
                                Text(rite.subtitle)
                                    .font(.custom("Georgia", size: 13))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(2)
                                    .lineSpacing(2)
                            }
                            Spacer()
                            if appSettings.missalRite == rite {
                                Circle()
                                    .fill(Color.sanctuaryRed)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                            } else {
                                Circle()
                                    .stroke(Color.goldLeaf.opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    appSettings.missalRite == rite
                                    ? Color.goldLeaf.opacity(0.4)
                                    : Color.goldLeaf.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                        .background(
                            appSettings.missalRite == rite
                            ? Color.goldLeaf.opacity(0.04)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                Text("You can change this anytime in settings.")
                    .font(.custom("Georgia-Italic", size: 13))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 8)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Bottom
            VStack(spacing: 16) {
                Button {
                    appSettings.hasCompletedOnboarding = true
                } label: {
                    Text("Begin Praying →")
                        .font(.custom("Palatino", size: 16).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.sanctuaryRed)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Page dots
                HStack(spacing: 8) {
                    Circle().fill(Color.goldLeaf.opacity(0.3)).frame(width: 8, height: 8)
                    Circle().fill(Color.sanctuaryRed).frame(width: 8, height: 8).scaleEffect(1.2)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "1C1410"), Color(hex: "1a1410")],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppSettings())
}
