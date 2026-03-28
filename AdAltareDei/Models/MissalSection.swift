import Foundation

/// Represents a section of the Latin Mass Ordinary (1962 Missal).
struct MissalSection: Identifiable, Codable {
    var id: String { slug }
    let slug: String
    let title: String
    let latinTitle: String
    let rubric: String
    let latinText: String
    let englishText: String
    let isProper: Bool  // true = changes daily (Introit, Collect, etc.)
    let sortOrder: Int
    let part: MassPart
}

enum MassPart: String, Codable, CaseIterable, Identifiable {
    case preparatory = "preparatory"
    case massOfCatechumens = "mass_of_catechumens"
    case massOfFaithful = "mass_of_faithful"
    case communion = "communion"
    case conclusion = "conclusion"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preparatory: return "Preparatory Prayers"
        case .massOfCatechumens: return "Mass of the Catechumens"
        case .massOfFaithful: return "Mass of the Faithful"
        case .communion: return "Communion"
        case .conclusion: return "Conclusion"
        }
    }

    var latinName: String {
        switch self {
        case .preparatory: return "Preces Praeparatoriae"
        case .massOfCatechumens: return "Missa Catechumenorum"
        case .massOfFaithful: return "Missa Fidelium"
        case .communion: return "Communio"
        case .conclusion: return "Conclusio"
        }
    }
}
