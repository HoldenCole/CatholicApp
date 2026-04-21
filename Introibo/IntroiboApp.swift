import SwiftUI

@main
struct IntroiboApp: App {
    @AppStorage("settings.darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}
