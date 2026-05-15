import SwiftUI

@main
struct IntroiboApp: App {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashFinished = false

    init() {
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
                    .onAppear { PrayerNotificationManager.scheduleAll() }
            }
        }
    }
}
