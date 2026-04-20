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
        .tint(.sanctuaryRed)
    }
}

#Preview { ContentView() }
