import SwiftUI

@main
struct IntroiboApp: App {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeRaw == "dark" ? .dark : .light)
        }
    }
}
