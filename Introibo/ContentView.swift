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
        // Inline contextual-link taps (Phase 2): BilingualLine renders links as
        // `introibo://link?t=<wireString>` URLs. Decode the target and dispatch
        // through the same DeepLinkRouter the search/related surfaces use.
        .onOpenURL { url in handleDeepLinkURL(url) }
    }

    /// Resolves an `introibo://link?t=…` URL into a navigation. Ignores any URL
    /// that isn't our scheme/host or whose `t` fails to parse — no-op on failure.
    private func handleDeepLinkURL(_ url: URL) {
        guard url.scheme == ContextualLink.scheme,
              url.host == ContextualLink.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "t" })?.value,
              let target = LinkTarget.parse(raw)
        else { return }
        DeepLinkRouter.shared.open(target)
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
