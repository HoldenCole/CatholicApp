import Foundation

struct MissalProperEntry: Decodable {
    let officium: String?
    let rank: Double?
    let rule: MissalRule?
    let introitus: ProperText?
    let oratio: ProperText?
    let lectio: ProperText?
    let graduale: ProperText?
    let evangelium: ProperText?
    let offertorium: ProperText?
    let secreta: ProperText?
    let communio: ProperText?
    let postcommunio: ProperText?

    struct MissalRule: Decodable {
        let gloria: Bool?
        let credo: Bool?
        let preface: String?
    }

    func toMassProper(key: String) -> MassProper? {
        guard let intro = introitus, let collect = oratio,
              let epistle = lectio, let gospel = evangelium,
              let off = offertorium, let sec = secreta,
              let comm = communio, let postcomm = postcommunio else {
            return nil
        }
        return MassProper(
            slug: key,
            title: officium ?? key,
            english: officium ?? key,
            rank: Int(rank ?? 0),
            color: "",
            season: nil,
            introit: intro,
            collect: collect,
            epistle: ProperReading(ref: epistle.ref ?? "", lat: epistle.lat, eng: epistle.eng),
            gradual: graduale,
            alleluia: nil,
            tract: nil,
            sequence: nil,
            gospel: ProperReading(ref: gospel.ref ?? "", lat: gospel.lat, eng: gospel.eng),
            offertory: off,
            secret: sec,
            communion: comm,
            postcommunion: postcomm,
            preface: rule?.preface
        )
    }
}

struct OrdoEntry: Decodable {
    let temporal: String?
    let sanctoral: String?
    let winner: String
    let winnerKey: String
    let rank: Double
    let name: String
    let color: String
    let season: String
    let commemoration: String?
}
