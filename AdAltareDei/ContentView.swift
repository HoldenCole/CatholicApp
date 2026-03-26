import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.horizon")
                }

            PrayerLibraryView()
                .tabItem {
                    Label("Prayers", systemImage: "book.pages")
                }

            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }
        }
        .tint(.sanctuaryRed)
        .task {
            if !hasSeeded {
                SampleData.seedIfNeeded(context: modelContext)
                hasSeeded = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
