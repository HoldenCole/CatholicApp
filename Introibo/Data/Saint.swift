import Foundation

// Matches Introibo/Resources/saints.json.
// Ported from prototype/saints.html's SAINTS object.

struct Saint: Identifiable, Decodable, Hashable {
    let slug: String
    let name: String
    let title: String
    let quote: String
    let penance: String?
    let penanceLatin: String?
    let sections: [Section]

    var id: String { slug }

    struct Section: Decodable, Hashable {
        let lat: String
        let eng: String
        let practices: [Practice]
    }

    struct Practice: Decodable, Hashable {
        let t: String   // title
        let d: String   // description
    }
}
