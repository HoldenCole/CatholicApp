import Foundation

// Matches Introibo/Resources/reference.json. Ported from
// prototype/reference.html's REFERENCE object. All fields except
// slug/title/cat/summary are optional per-entry.

struct ReferenceEntry: Identifiable, Decodable, Hashable {
    let slug: String
    let title: String
    let latin: String?
    let cat: String                 // Category label
    let summary: String
    let history: String?
    let practice: String?
    let notes: String?
    let scripture: Scripture?

    var id: String { slug }

    struct Scripture: Decodable, Hashable {
        let ref: String
        let lat: String
        let eng: String
    }
}
