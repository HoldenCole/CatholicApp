import Foundation

// Matches Introibo/Resources/saints.json.
// Ported from prototype/saints.html's SAINTS object.

struct Saint: Identifiable, Decodable, Hashable {
    let slug: String
    var name: String
    var title: String
    var quote: String
    var penance: String?
    let penanceLatin: String?
    var sections: [Section]
    var prayers: [SaintPrayer]?
    var related: [RelatedLink]? = nil

    var id: String { slug }

    struct Section: Decodable, Hashable {
        let lat: String
        var eng: String
        var practices: [Practice]
    }

    struct Practice: Decodable, Hashable {
        var t: String
        var d: String
    }

    struct SaintPrayer: Decodable, Hashable, Identifiable {
        var title: String
        let latin: String?
        var eng: String
        var note: String?

        var id: String { title }
    }
}
