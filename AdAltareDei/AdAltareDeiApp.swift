import SwiftUI
import SwiftData

@main
struct AdAltareDeiApp: App {
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.darkModeEnabled ? .dark : .light)
        }
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self])
    }
}
