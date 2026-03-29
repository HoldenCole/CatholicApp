import Foundation

/// A reference entry — a prayer, devotion, practice, or concept with full background info.
struct ReferenceEntry: Identifiable, Codable {
    var id: String { slug }
    let slug: String
    let title: String
    let latinTitle: String
    let category: ReferenceCategory
    let sortOrder: Int
    let summary: String           // One-line shown in the list
    let history: String           // Historical background
    let explanation: String       // What it is and why it matters
    let practice: String?         // How/when to do it
    let scriptureRefs: [String]?           // Relevant scripture references
    let scriptureExplanation: String?      // Why this is biblical / scripture context
    let theologianQuotes: [TheologianQuote]? // What saints and theologians say
    let churchTeaching: String?            // Magisterial references
    let relatedEntries: [String]?          // Slugs of related entries
}

struct TheologianQuote: Codable {
    let author: String
    let quote: String
    let source: String?
}

enum ReferenceCategory: String, Codable, CaseIterable, Identifiable {
    case prayers = "prayers"
    case massAndSacraments = "mass_and_sacraments"
    case devotions = "devotions"
    case fastingAndPenance = "fasting_and_penance"
    case liturgicalCalendar = "liturgical_calendar"
    case latin = "latin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .prayers: return "Prayers"
        case .massAndSacraments: return "Mass & Sacraments"
        case .devotions: return "Devotions"
        case .fastingAndPenance: return "Fasting & Penance"
        case .liturgicalCalendar: return "Liturgical Calendar"
        case .latin: return "Latin"
        }
    }

    var latinName: String {
        switch self {
        case .prayers: return "Orationes"
        case .massAndSacraments: return "Missa et Sacramenta"
        case .devotions: return "Devotiones"
        case .fastingAndPenance: return "Ieiunium et Pænitentia"
        case .liturgicalCalendar: return "Calendarium Liturgicum"
        case .latin: return "Lingua Latina"
        }
    }

    var icon: String {
        switch self {
        case .prayers: return "hands.and.sparkles"
        case .massAndSacraments: return "building.columns"
        case .devotions: return "heart"
        case .fastingAndPenance: return "fork.knife"
        case .liturgicalCalendar: return "calendar"
        case .latin: return "character.book.closed"
        }
    }
}
