import Foundation

/// Represents a Latin learning course/lesson.
struct LatinLesson: Identifiable, Codable {
    var id: String { slug }
    let slug: String
    let title: String
    let latinTitle: String
    let description: String
    let category: LessonCategory
    let sortOrder: Int
    let isPremium: Bool
    let estimatedMinutes: Int
}

enum LessonCategory: String, Codable, CaseIterable, Identifiable {
    case pronunciation = "pronunciation"
    case grammar = "grammar"
    case prayers = "prayers"
    case massResponses = "mass_responses"
    case reading = "reading"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pronunciation: return "Pronunciation"
        case .grammar: return "Grammar Basics"
        case .prayers: return "Prayer Courses"
        case .massResponses: return "Mass Responses"
        case .reading: return "Latin Reading"
        }
    }

    var latinName: String {
        switch self {
        case .pronunciation: return "Pronuntiatio"
        case .grammar: return "Grammatica"
        case .prayers: return "Orationes"
        case .massResponses: return "Responsa Missæ"
        case .reading: return "Lectio Latina"
        }
    }

    var icon: String {
        switch self {
        case .pronunciation: return "waveform"
        case .grammar: return "textformat.abc"
        case .prayers: return "hands.and.sparkles"
        case .massResponses: return "person.2"
        case .reading: return "text.book.closed"
        }
    }
}
