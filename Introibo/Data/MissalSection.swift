import Foundation

// Matches Introibo/Resources/missal.json.
// 13 sections of the Ordinary of the Mass, in order.

struct MissalSection: Identifiable, Decodable, Hashable {
    let slug: String
    let label: String?
    let title: String
    // Vernacular fields are `var` so the Spanish overlay can rewrite them
    // in place (ContentStore.applyVernacularOverlay).
    var english: String?
    var body: [Line]

    var id: String { slug }

    struct Line: Decodable, Hashable {
        var lat: String
        var eng: String
        var rubric: String? = nil
    }
}
