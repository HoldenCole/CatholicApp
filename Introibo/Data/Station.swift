import Foundation

// Matches Introibo/Resources/stations.json — 14 stations, ordered.

struct Station: Identifiable, Decodable, Hashable {
    let station: String     // Roman numeral I...XIV
    var title: String
    let latin: String
    var med: String         // Meditation
    let mood: String        // "" | "mood-mother" | "mood-death" | "mood-tomb"
    let stabat_lat: String
    var stabat_eng: String

    var id: String { station }
}
