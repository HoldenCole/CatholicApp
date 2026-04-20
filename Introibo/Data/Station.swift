import Foundation

// Matches Introibo/Resources/stations.json — 14 stations, ordered.

struct Station: Identifiable, Decodable, Hashable {
    let station: String     // Roman numeral I...XIV
    let title: String
    let latin: String
    let med: String         // Meditation
    let mood: String        // "" | "mood-mother" | "mood-death" | "mood-tomb"
    let stabat_lat: String
    let stabat_eng: String

    var id: String { station }
}
