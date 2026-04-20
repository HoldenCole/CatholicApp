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
        .tint(.sanctuaryRed)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.pageTitle)
                .foregroundStyle(.primaryText)
            Text(subtitle)
                .smallLabel()
            Spacer()
            Text("Under construction")
                .font(.captionSm)
                .foregroundStyle(.tertiaryText)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageChrome()
    }
}

#Preview {
    ContentView()
}
