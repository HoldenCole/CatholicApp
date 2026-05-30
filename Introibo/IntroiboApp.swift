import SwiftUI

@main
struct IntroiboApp: App {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashFinished = false
    @State private var showUpgradeModal = false
    private var tutorial: TutorialManager { TutorialManager.shared }

    init() {
        // Build the search index off the main thread so the first Search use
        // doesn't pay the fold/index cost synchronously. Idempotent.
        ContentStore.shared.prepareSearchIndex()

        // Migration: existing users who already have settings should skip onboarding
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            if UserDefaults.standard.string(forKey: SettingsKey.rite) != nil
                || UserDefaults.standard.string(forKey: SettingsKey.language) != nil
                || UserDefaults.standard.string(forKey: SettingsKey.theme) != nil {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .preferredColorScheme(.light)
            } else if !splashFinished {
                SplashView(isFinished: $splashFinished)
                    .preferredColorScheme(.dark)
            } else {
                ContentView()
                    .preferredColorScheme(themeRaw == "dark" ? .dark : .light)
                    .onAppear {
                        PrayerNotificationManager.scheduleAll()
                        // New user: start main tutorial after 2s delay
                        if !tutorial.mainTutorialCompleted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                tutorial.startMainTutorial()
                            }
                        }
                        // Existing user: show upgrade modal after a brief delay
                        else if !tutorial.upgradeTutorialPrompted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showUpgradeModal = true
                            }
                        }
                    }
                    .alert("Introibo has been improved throughout.", isPresented: $showUpgradeModal) {
                        Button("Take the tour") { tutorial.startUpgradeTutorial() }
                        Button("Skip", role: .cancel) { tutorial.upgradeTutorialPrompted = true }
                    } message: {
                        Text("Would you like a quick tour of what\u{2019}s new?")
                    }
            }
        }
    }
}
