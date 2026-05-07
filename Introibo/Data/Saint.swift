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
    let prayers: [SaintPrayer]?

    var id: String { slug }

    struct Section: Decodable, Hashable {
        let lat: String
        let eng: String
        let practices: [Practice]
    }

    struct Practice: Decodable, Hashable {
        let t: String
        let d: String
    }

    struct SaintPrayer: Decodable, Hashable, Identifiable {
        let title: String
        let latin: String?
        let eng: String
        let note: String?

        var id: String { title }
    }
}
