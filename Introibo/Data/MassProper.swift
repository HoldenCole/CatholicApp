import Foundation

struct MassProper: Identifiable, Decodable, Hashable {
    let slug: String
    let title: String
    let english: String
    let rank: Int
    let color: String
    let season: String?
    let introit: ProperText
    let collect: ProperText
    let epistle: ProperReading
    let gradual: ProperText?
    let alleluia: ProperText?
    let tract: ProperText?
    let sequence: ProperText?
    let gospel: ProperReading
    let offertory: ProperText
    let secret: ProperText
    let communion: ProperText
    let postcommunion: ProperText
    let preface: String?
    // Optional rubric hints from DO data (rule.gloria, rule.credo).
    // When present, override the rank-based heuristic.
    var glorOverride: Bool? = nil
    var credoOverride: Bool? = nil

    var id: String { slug }
}

struct ProperText: Decodable, Hashable {
    let lat: String
    let eng: String
    var ref: String? = nil
}

struct ProperReading: Decodable, Hashable {
    let ref: String
    let lat: String
    let eng: String
}
