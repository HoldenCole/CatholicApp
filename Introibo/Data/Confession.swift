import Foundation

// Matches Introibo/Resources/confession_examen.json.
// Each commandment has its English commandment text, Latin form,
// and a short list of self-examination questions.

struct ExamenEntry: Identifiable, Decodable, Hashable {
    let num: String         // Roman numeral I...X
    let commandment: String
    let latin: String
    let questions: [String]

    var id: String { num }
}

// Matches Introibo/Resources/confession_guides.json.
// Two guided paths ("Liber I" guided, "Liber II" after St. Catherine).

struct ConfessionGuide: Identifiable, Decodable, Hashable {
    let slug: String
    let name: String
    let title: String
    let subtitle: String?
    let steps: [Step]

    var id: String { slug }

    struct Step: Decodable, Hashable {
        let num: String       // i, ii, iii, ...
        let title: String
        let latin: String?
        let body: String
    }
}
