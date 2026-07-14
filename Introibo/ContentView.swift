import SwiftUI

struct ContentView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    private var tutorialManager: TutorialManager { TutorialManager.shared }

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .parchment }

    @State private var spotlightFrames: [String: CGRect] = [:]
    @State private var selectedTab = 0
    @State private var router = DeepLinkRouter.shared

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
        // Deep-link navigation (Phase 3): when the router stages a resolved
        // target, switch to the owning tab and present the detail at the root.
        .onChange(of: router.requestedTab) { _, newTab in
            if let tab = newTab { selectedTab = tab }
        }
        .sheet(item: Binding(
            get: { router.resolved },
            set: { if $0 == nil { router.consume() } }
        )) { resolved in
            deepLinkDestination(resolved)
        }
        // URL entry (contextual links + widget taps) is attached at the App
        // root (IntroiboApp) so cold launches during the splash are not lost;
        // the router stages the navigation and this view presents it above.
    }

    /// Maps a resolved deep link to its detail view, threading the scroll anchor.
    @ViewBuilder
    private func deepLinkDestination(_ resolved: DeepLinkResolved) -> some View {
        switch resolved {
        case .prayer(let p, let anchor):
            PrayerDetailView(prayer: p, initialAnchor: anchor)
        case .proper(let mp, let anchor):
            ProperView(proper: mp, initialAnchor: anchor)
        case .missalSection(let mp, let anchor):
            ProperView(proper: mp, initialAnchor: anchor)
        case .hour(let h, let anchor):
            HourView(hour: h, initialAnchor: anchor)
        case .reference(let e, let anchor):
            ReferenceDetailView(entry: e, initialAnchor: anchor)
        case .saint(let s, let anchor):
            SaintDetailView(saint: s, initialAnchor: anchor)
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
