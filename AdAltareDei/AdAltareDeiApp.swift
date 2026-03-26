import SwiftUI
import SwiftData

@main
struct AdAltareDeiApp: App {
    @StateObject private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
        }
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self])
    }
}
