import Foundation

// Matches Introibo/Resources/mysteries.json.
// 3 sets (joyful, sorrowful, glorious), 5 mysteries each.

struct MysterySetData: Identifiable, Decodable, Hashable {
    let slug: String            // joyful | sorrowful | glorious
    let name: String            // Mystéria Gaudiósa etc
    let english: String         // Joyful Mysteries etc
    let mysteries: [Mystery]

    var id: String { slug }
}

struct Mystery: Decodable, Hashable {
    let num: String             // "Mystérium Primum" etc
    let title: String           // Latin title
    let eng: String             // English title
    let ref: String             // Scripture reference
    let body: String            // Meditation paragraph
    let fruit: String           // Fruit of the mystery
}

// Matches Introibo/Resources/rosary_prayers.json.
// The 7 core prayers needed for the Rosary (signum, credo, pater, ave,
// gloria, fatima, salve), with Latin + English.
struct RosaryPrayer: Identifiable, Decodable, Hashable {
    let slug: String
    let title: String
    let eng: String
    let lines: [Line]

    var id: String { slug }

    struct Line: Decodable, Hashable {
        let lat: String
        let eng: String
    }
}
