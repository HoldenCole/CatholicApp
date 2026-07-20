import SwiftUI

@main
struct IntroiboApp: App {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var splashFinished = false
    @State private var showUpgradeModal = false
    @Environment(\.scenePhase) private var scenePhase
    private var tutorial: TutorialManager { TutorialManager.shared }

    init() {
        // Build the search index off the main thread so the first Search use
        // doesn't pay the fold/index cost synchronously. Idempotent.
        ContentStore.shared.prepareSearchIndex()
        // Build the contextual-link reverse index off the main thread too, so the
        // first "Referenced By" block doesn't pay the scan cost synchronously.
        ContentStore.shared.prepareLinkGraph()

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
            Group {
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
            // Deep-link URL entry (inline contextual links + widget taps).
            // Attached at the App root — NOT only inside ContentView — so a
            // cold launch from a widget tap during the splash still stages
            // the navigation; ContentView presents it when it mounts.
            .onOpenURL { url in
                DeepLinkRouter.shared.open(url: url)
            }
            // Refresh the widget snapshot window (feast + propers quotes for
            // the next 30 days) on every foreground — the widget extension
            // can't compute these itself. Cheap; runs off the main thread.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    DispatchQueue.global(qos: .utility).async {
                        WidgetSnapshotWriter.refresh()
                    }
                }
            }
        }
    }
}
