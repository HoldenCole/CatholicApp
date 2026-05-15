import SwiftUI

struct ContentView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    private var tutorialManager: TutorialManager { TutorialManager.shared }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .parchment }

    @State private var spotlightFrames: [String: CGRect] = [:]

    var body: some View {
        ZStack {
            TabView {
                TodayView()
                    .tabItem { Label("Hodie", systemImage: "sun.horizon") }

                MissalView()
                    .tabItem { Label("Missa", systemImage: "book.closed") }

                PrayersView()
                    .tabItem { Label("Oratio", systemImage: "book.pages") }

                LearnView()
                    .tabItem { Label("Schola", systemImage: "graduationcap") }

                ReferenceView()
                    .tabItem { Label("Liber", systemImage: "text.book.closed") }
            }
            .tint(Color.sanctuaryRed)
            .onPreferenceChange(SpotlightFrameKey.self) { frames in
                spotlightFrames = frames
            }

            TutorialOverlay(
                manager: tutorialManager,
                spotlightFrames: spotlightFrames
            )
        }
        .onAppear { updateTabBar() }
        .onChange(of: themeRaw) { _, _ in updateTabBar() }
    }

    private func updateTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        switch theme {
        case .parchment:
            appearance.backgroundColor = UIColor(Color.parchment)
        case .white:
            appearance.backgroundColor = UIColor(.white)
        case .dark:
            appearance.backgroundColor = UIColor(Color.walnut)
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview { ContentView() }
