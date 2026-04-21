import Foundation

// Matches Introibo/Resources/missal.json.
// 13 sections of the Ordinary of the Mass, in order.

struct MissalSection: Identifiable, Decodable, Hashable {
    let slug: String
    let label: String?
    let title: String
    let english: String?
    let body: [Line]

    var id: String { slug }

    struct Line: Decodable, Hashable {
        let lat: String
        let eng: String
    }
}
