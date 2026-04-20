import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PlaceholderScreen(title: "Hódie", subtitle: "Today")
                .tabItem { Label("Hódie", systemImage: "sun.horizon") }

            PlaceholderScreen(title: "Missa", subtitle: "Missal")
                .tabItem { Label("Missa", systemImage: "book.closed") }

            PlaceholderScreen(title: "Orátio", subtitle: "Prayers")
                .tabItem { Label("Orátio", systemImage: "book.pages") }

            PlaceholderScreen(title: "Schola", subtitle: "Learn")
                .tabItem { Label("Schola", systemImage: "graduationcap") }

            PlaceholderScreen(title: "Liber", subtitle: "Reference")
                .tabItem { Label("Liber", systemImage: "text.book.closed") }
        }
        .tint(Color(red: 139/255, green: 26/255, blue: 26/255))
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .italic()
            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(2)
        }
    }
}

#Preview {
    ContentView()
}
