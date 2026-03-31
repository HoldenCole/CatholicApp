import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("defaultTextMode") var defaultTextMode: TextMode = .missal
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("currentStreak") var currentStreak = 0
    @AppStorage("lastPracticeDate") var lastPracticeDate = ""
    @AppStorage("missalRite") var missalRite: MissalRite = .rubrics1962
    @AppStorage("penanceDiscipline") var penanceDiscipline: PenanceDiscipline = .modern1962
    @AppStorage("darkModeEnabled") var darkModeEnabled = false

    // Course completion tracking
    var completedCourses: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "completedCourses") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "completedCourses")
            objectWillChange.send()
        }
    }

    func markCourseCompleted(_ slug: String) {
        var courses = completedCourses
        courses.insert(slug)
        completedCourses = courses
    }

    func isCourseCompleted(_ slug: String) -> Bool {
        completedCourses.contains(slug)
    }

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

// MARK: - Penance Discipline

enum PenanceDiscipline: String, CaseIterable, Identifiable {
    case modern1962 = "1962"
    case traditional1917 = "1917"
    case strict = "strict"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modern1962: return "1962 Discipline"
        case .traditional1917: return "1917 Code"
        case .strict: return "Strict Traditional"
        }
    }

    var latinName: String {
        switch self {
        case .modern1962: return "Disciplina 1962"
        case .traditional1917: return "Codex Iuris Canonici 1917"
        case .strict: return "Disciplina Stricta"
        }
    }

    var subtitle: String {
        switch self {
        case .modern1962:
            return "Friday abstinence from meat. Fasting on Ash Wednesday and Good Friday. The minimum discipline observed by most traditional Catholics today."
        case .traditional1917:
            return "The full 1917 Code of Canon Law discipline: Friday abstinence year-round, Lenten fasting all weekdays, Ember Days, Vigil fasts. The discipline binding before 1966."
        case .strict:
            return "The most rigorous traditional practice: all 1917 Code penances plus Wednesday and Saturday abstinence, additional vigil fasts, and following the penance practices of your chosen saint."
        }
    }

    /// Returns the penance items applicable for today under this discipline.
    func penancesForToday(date: Date = Date()) -> [PenanceItem] {
        let weekday = Calendar.current.component(.weekday, from: date)
        // 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        var items: [PenanceItem] = []

        // Friday abstinence — all disciplines
        if weekday == 6 {
            items.append(PenanceItem(
                title: "Friday Abstinence",
                latinTitle: "Abstinentia Feriæ Sextæ",
                description: "Abstain from meat.",
                isAbstinence: true, isFasting: false
            ))
        }

        // Wednesday abstinence — strict only
        if weekday == 4 && self == .strict {
            items.append(PenanceItem(
                title: "Wednesday Abstinence",
                latinTitle: "Abstinentia Feriæ Quartæ",
                description: "Abstain from meat.",
                isAbstinence: true, isFasting: false
            ))
        }

        // Saturday partial abstinence — 1917 and strict
        if weekday == 7 && (self == .traditional1917 || self == .strict) {
            items.append(PenanceItem(
                title: "Saturday Abstinence",
                latinTitle: "Abstinentia Sabbati",
                description: "Partial abstinence — meat permitted only at the principal meal.",
                isAbstinence: true, isFasting: false
            ))
        }

        return items
    }
}

struct PenanceItem {
    let title: String
    let latinTitle: String
    let description: String
    let isAbstinence: Bool
    let isFasting: Bool
}
