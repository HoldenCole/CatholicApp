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
    // Optional propers using DO's Latin field names. Currently absent from
    // missal_tempora.json / missal_sanctoral.json but threaded so that any
    // future data additions surface in the rendered MassProper.
    let alleluia: ProperText?
    let tractus: ProperText?
    let sequentia: ProperText?

    struct MissalRule: Decodable {
        let gloria: Bool?
        let credo: Bool?
        let preface: String?
        /// Optional redirect to another formulary used as a fallback when this
        /// entry omits the Mass propers. Format: "Sancti/12-25m3", "Tempora/Epi3-0",
        /// "C5" (commune key), or a bare missal key like "epi3-0".
        let commune: String?
    }

    func toMassProper(key: String, ordo: OrdoEntry? = nil) -> MassProper? {
        guard let intro = introitus, let collect = oratio,
              let epistle = lectio, let gospel = evangelium,
              let off = offertorium, let sec = secreta,
              let comm = communio, let postcomm = postcommunio else {
            return nil
        }
        // DO rank scale: 1.0=ferial, 7.0=highest. Legacy: 1=highest, 5=ferial.
        // Convert so existing rank-based checks behave correctly.
        let doRank = rank ?? 0
        let legacyRank: Int
        if doRank >= 6.0 { legacyRank = 1 }      // 1st class
        else if doRank >= 5.0 { legacyRank = 2 } // 2nd class
        else if doRank >= 4.0 { legacyRank = 3 } // 3rd class
        else if doRank >= 3.0 { legacyRank = 4 } // 4th class
        else { legacyRank = 5 }                   // ferial / commemoration

        return MassProper(
            slug: key,
            title: officium ?? key,
            english: officium ?? key,
            rank: legacyRank,
            color: ordo?.color ?? "",
            season: ordo?.season,
            introit: intro,
            collect: collect,
            epistle: ProperReading(ref: epistle.ref ?? "", lat: epistle.lat, eng: epistle.eng),
            gradual: graduale,
            alleluia: alleluia,
            tract: tractus,
            sequence: sequentia,
            gospel: ProperReading(ref: gospel.ref ?? "", lat: gospel.lat, eng: gospel.eng),
            offertory: off,
            secret: sec,
            communion: comm,
            postcommunion: postcomm,
            preface: Self.translatePrefaceCode(rule?.preface),
            glorOverride: rule?.gloria,
            credoOverride: rule?.credo
        )
    }

    /// Translates DivinumOfficium preface codes to the slug suffix used by missal.json.
    /// e.g., "Nat" → "nativity", "Pasch" → "easter", "Quad" → "lent".
    static func translatePrefaceCode(_ code: String?) -> String? {
        guard let raw = code, !raw.isEmpty else { return nil }
        // DO codes like "Spiritu=hodierna die" or "Joseph=Festivitáte" have suffix qualifiers.
        // Take just the base code (before "=" or ";").
        let base = raw.split(whereSeparator: { $0 == "=" || $0 == ";" }).first.map(String.init) ?? raw
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "Nat", "Nativitate": return "nativity"
        case "Pasch", "Pasc", "Paschalis", "Paschali": return "easter"
        case "Quad", "Quadragesimale", "Quaragesimale": return "lent"
        case "Quad5": return "cross"
        case "Asc", "Ascensione": return "ascension"
        case "Spiritu", "Pentecostes": return "pentecost"
        case "Epi", "Epiphania": return "epiphany"
        case "Trinitate", "Trinitatis": return "trinity"
        case "Joseph", "Josephi": return "joseph"
        case "Maria", "BMV", "Mariae": return "bvm"
        case "Apos", "Apostolis", "Apostolorum": return "apostles"
        case "Cruc", "Cruce", "Crucis": return "cross"
        case "Adv", "Adventus": return "advent"
        case "Requiem", "Defunctorum": return "requiem"
        case "Cord", "CordJesu", "Cordis": return "sacred-heart"
        case "Regis", "ChristiRegis", "Rex": return "christ-king"
        case "Communis", "Common", "": return nil
        default: return nil // unknown code → fall through to common preface
        }
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
