import SwiftUI

struct ContentView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? Color.parchment }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Hódie", systemImage: "sun.horizon") }

            MissalView()
                .tabItem { Label("Missa", systemImage: "book.closed") }

            PrayersView()
                .tabItem { Label("Orátio", systemImage: "book.pages") }

            LearnView()
                .tabItem { Label("Schola", systemImage: "graduationcap") }

            ReferenceView()
                .tabItem { Label("Liber", systemImage: "text.book.closed") }
        }
        .tint(Color.sanctuaryRed)
        .onAppear { updateTabBar() }
        .onChange(of: themeRaw) { _, _ in updateTabBar() }
    }

    private func updateTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        switch theme {
        case Color.parchment:
            appearance.backgroundColor = UIColor(Color.parchment)
        case .white:
            appearance.backgroundColor = UIColor(Color.walnut)
        case .dark:
            appearance.backgroundColor = UIColor(Color.walnut)
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview { ContentView() }
