import Foundation

// Matches Introibo/Resources/courses.json.
// Ported from prototype/learn.html's COURSES object.

struct Course: Identifiable, Decodable, Hashable {
    let slug: String
    let num: Int
    let title: String
    let latin: String
    let intro: String
    let sections: [Section]

    var id: String { slug }

    struct Section: Decodable, Hashable {
        let type: String         // lesson | tip | cards | summary | phrase | table
        let label: String?
        let html: String?        // present for lesson/tip/summary/phrase/table
        let note: String?        // present for cards
        let items: [Card]?       // present for cards

        struct Card: Decodable, Hashable {
            let lat: String?
            let phon: String?
            let eng: String?
        }
    }
}
