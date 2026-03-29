import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @State private var hasSeeded = false

    var body: some View {
        Group {
            if appSettings.hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView()
            }
        }
        .task {
            if !hasSeeded {
                SampleData.seedIfNeeded(context: modelContext)
                hasSeeded = true
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.horizon")
                }

            MissalView()
                .tabItem {
                    Label("Missal", systemImage: "book.closed")
                }

            PrayerLibraryView()
                .tabItem {
                    Label("Prayers", systemImage: "book.pages")
                }

            LearnView()
                .tabItem {
                    Label("Learn", systemImage: "graduationcap")
                }

            ReferenceView()
                .tabItem {
                    Label("Reference", systemImage: "text.book.closed")
                }
        }
        .tint(.sanctuaryRed)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
