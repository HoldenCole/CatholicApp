import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("defaultTextMode") var defaultTextMode: TextMode = .english
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("currentStreak") var currentStreak = 0
    @AppStorage("lastPracticeDate") var lastPracticeDate = ""

    func recordPractice() {
        let today = Date().dateKey
        if lastPracticeDate == today { return }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())?.dateKey ?? ""
        if lastPracticeDate == yesterday {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
        lastPracticeDate = today
    }
}

enum TextMode: String, CaseIterable, Identifiable {
    case english
    case latin
    case phonetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .latin: return "Latin"
        case .phonetic: return "Phonetic"
        }
    }
}
