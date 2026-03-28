import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("defaultTextMode") var defaultTextMode: TextMode = .missal
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("currentStreak") var currentStreak = 0
    @AppStorage("lastPracticeDate") var lastPracticeDate = ""
    @AppStorage("isPremium") var isPremium = false
    @AppStorage("missalRite") var missalRite: MissalRite = .rubrics1962

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

// MARK: - Missal Rite / Rubrical Year

enum MissalRite: String, CaseIterable, Identifiable {
    case rubrics1962 = "1962"
    case rubrics1955 = "1955"
    case rubricsPre1955 = "pre1955"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rubrics1962: return "1962 Missal"
        case .rubrics1955: return "1955 Missal"
        case .rubricsPre1955: return "Pre-1955 Missal"
        }
    }

    var latinName: String {
        switch self {
        case .rubrics1962: return "Missale Romanum 1962"
        case .rubrics1955: return "Missale Romanum 1955"
        case .rubricsPre1955: return "Missale Romanum (ante 1955)"
        }
    }

    var subtitle: String {
        switch self {
        case .rubrics1962: return "Post-Johannine rubrics. Most common form used by FSSP, ICKSP, and diocesan TLM communities."
        case .rubrics1955: return "Post-Pius XII Holy Week reform but pre-1960 rubrical changes. Used by some traditional communities."
        case .rubricsPre1955: return "Pre-Pius XII rubrics with original Holy Week. Used by some SSPX chapels and independent traditional communities."
        }
    }

    var keyDifferences: [String] {
        switch self {
        case .rubrics1962:
            return [
                "Simplified rubrics from 1960 Code",
                "Reduced octaves and vigils",
                "Confiteor said once at Communion",
                "St. Joseph added to Canon"
            ]
        case .rubrics1955:
            return [
                "Restored Holy Week (1955 reform)",
                "Original octave and vigil system mostly intact",
                "Double Confiteor at Communion",
                "Pre-1960 ranking of feasts"
            ]
        case .rubricsPre1955:
            return [
                "Original Holy Week (pre-1955)",
                "Full octave system intact",
                "Double Confiteor at Communion",
                "Traditional feast ranking system",
                "Palm Sunday with full procession rubrics"
            ]
        }
    }
}

enum TextMode: String, CaseIterable, Identifiable {
    case missal
    case english
    case latin
    case phonetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .missal: return "Missal"
        case .english: return "English"
        case .latin: return "Latin"
        case .phonetic: return "Phonetic"
        }
    }
}
