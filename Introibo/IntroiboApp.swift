import SwiftUI

@main
struct IntroiboApp: App {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashFinished = false

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
            }
        }
    }
}
