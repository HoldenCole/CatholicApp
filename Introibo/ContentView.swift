import SwiftUI

struct ContentView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    private var tutorialManager: TutorialManager { TutorialManager.shared }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .parchment }

    @State private var spotlightFrames: [String: CGRect] = [:]
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem { Label("Hodie", systemImage: "sun.horizon") }
                    .tag(0)

                MissalView()
                    .tabItem { Label("Missa", systemImage: "book.closed") }
                    .tag(1)

                PrayersView()
                    .tabItem { Label("Oratio", systemImage: "book.pages") }
                    .tag(2)

                LearnView()
                    .tabItem { Label("Schola", systemImage: "graduationcap") }
                    .tag(3)

                ReferenceView()
                    .tabItem { Label("Liber", systemImage: "text.book.closed") }
                    .tag(4)
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
        .onChange(of: tutorialManager.targetTabIndex) { _, newTab in
            if let tab = newTab {
                withAnimation { selectedTab = tab }
            }
        }
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
