import SwiftUI

struct ContentView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage("hasSeenTutorialOffer") private var hasSeenTutorialOffer = false
    @State private var showTutorialOffer = false
    @State private var showTutorial = false

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .parchment }

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
        .onAppear {
            updateTabBar()
            if !hasSeenTutorialOffer {
                hasSeenTutorialOffer = true
                showTutorialOffer = true
            }
        }
        .onChange(of: themeRaw) { _, _ in updateTabBar() }
        .alert("Welcome to Introibo", isPresented: $showTutorialOffer) {
            Button("Take a Tour") { showTutorial = true }
            Button("No Thanks", role: .cancel) { }
        } message: {
            Text("Would you like a quick walkthrough of the app?")
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView()
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
