import Foundation

// Matches Introibo/Resources/reference.json. Ported from
// prototype/reference.html's REFERENCE object. All fields except
// slug/title/cat/summary are optional per-entry.

struct ReferenceEntry: Identifiable, Decodable, Hashable {
    let slug: String
    var title: String
    let latin: String?
    let cat: String                 // Category label
    var summary: String
    var history: String?
    var practice: String?
    var notes: String?
    var scripture: Scripture?
    var related: [RelatedLink]? = nil

    var id: String { slug }

    struct Scripture: Decodable, Hashable {
        let ref: String
        let lat: String
        var eng: String
    }
}
