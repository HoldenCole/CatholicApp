import SwiftUI

struct ContentView: View {
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
            // Parchment tab bar background instead of default white
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color.parchment)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview { ContentView() }
