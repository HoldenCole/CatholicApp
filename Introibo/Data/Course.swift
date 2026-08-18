import Foundation

// Matches Introibo/Resources/courses.json.
// Ported from prototype/learn.html's COURSES object.

struct Course: Identifiable, Decodable, Hashable {
    let slug: String
    let num: Int
    var title: String
    let latin: String
    var intro: String
    var sections: [Section]

    var id: String { slug }

    struct Section: Decodable, Hashable {
        let type: String         // lesson | tip | cards | summary | phrase | table
        var label: String?
        var html: String?        // present for lesson/tip/summary/phrase/table
        var note: String?        // present for cards
        var items: [Card]?       // present for cards

        struct Card: Decodable, Hashable {
            let lat: String?
            var phon: String?
            var eng: String?
        }
    }
}
