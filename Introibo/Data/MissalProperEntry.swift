import Foundation

struct MissalProperEntry: Decodable {
    let officium: String?
    let rank: Double?
    let rule: MissalRule?
    var introitus: ProperText?
    var oratio: ProperText?
    var lectio: ProperText?
    var graduale: ProperText?
    var evangelium: ProperText?
    var offertorium: ProperText?
    var secreta: ProperText?
    var communio: ProperText?
    var postcommunio: ProperText?
    // DO's seasonal forms of the Gradual: gradualeP in Paschaltide, tractus
    // from Septuagesima to Holy Saturday (each with its Gradual verses, as
    // DO's getitem() takes it in place of [Graduale]).
    var gradualeP: ProperText?
    let alleluia: ProperText?
    var tractus: ProperText?
    var sequentia: ProperText?

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

        let latinTitle = officium ?? key
        let season = ordo?.season
        let paschal = season == "easter"
        // The Gradual the season takes (DO's getitem): the Paschal form in
        // Eastertide, the Tract from Septuagesima, otherwise the Gradual.
        let gradualForSeason: ProperText?
        if paschal, let p = gradualeP { gradualForSeason = p }
        else if season == "lent" || season == "pre-lent", let t = tractus { gradualForSeason = t }
        else { gradualForSeason = graduale }
        let lenten = season == "lent" || season == "pre-lent"
        let a: (ProperText) -> ProperText = { Self.seasonalAlleluia($0, paschal: paschal, lenten: lenten) }

        return MassProper(
            slug: key,
            title: latinTitle,
            english: latinTitle,
            rank: legacyRank,
            color: ordo?.color ?? "",
            season: ordo?.season,
            introit: a(intro),
            collect: collect,
            epistle: ProperReading(ref: epistle.ref ?? "", lat: epistle.lat, eng: epistle.eng),
            gradual: gradualForSeason.map(a),
            alleluia: alleluia,
            tract: nil,
            sequence: sequentia,
            gospel: ProperReading(ref: gospel.ref ?? "", lat: gospel.lat, eng: gospel.eng),
            offertory: a(off),
            secret: sec,
            communion: a(comm),
            postcommunion: postcomm,
            preface: Self.translatePrefaceCode(rule?.preface),
            glorOverride: rule?.gloria,
            credoOverride: rule?.credo
        )
    }

    /// The bracketed alleluias of the Commons, "(Allelúja, allelúja.)": said
    /// in Paschaltide (the brackets dropped), left out otherwise, as DO's
    /// getitem() does. Latin, English, Spanish and French forms.
    private static let bracketedAlleluia = try! NSRegularExpression(
        pattern: #"\s*\(((?:Al+[eé]l[uú][ij]a|Aleluya)[^()]*)\)"#, options: [.caseInsensitive])

    static func paschalAlleluia(_ text: String, paschal: Bool) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return bracketedAlleluia.stringByReplacingMatches(in: text, range: range,
                                                          withTemplate: paschal ? " $1" : "")
    }

    /// A chant's closing alleluia ("… eórum, allelúja."), left out from
    /// Septuagesima to Holy Saturday as DO's "(sed post Septuagesimam
    /// dicitur)" does. A line that is nothing but alleluias stays.
    private static let closingAlleluia = try! NSRegularExpression(
        pattern: #"[,;:.]?\s*(?:(?:Al+[eé]l[uú][ij]a|Aleluya)[,.]?\s*)+$"#, options: [.caseInsensitive])
    private static let onlyAlleluia = try! NSRegularExpression(
        pattern: #"^\s*(?:V\.\s*)?(?:(?:Al+[eé]l[uú][ij]a|Aleluya)[,.]?\s*)+$"#, options: [.caseInsensitive])

    static func lentenAlleluia(_ text: String) -> String {
        text.components(separatedBy: "\n").map { line -> String in
            let r = NSRange(line.startIndex..., in: line)
            if onlyAlleluia.firstMatch(in: line, range: r) != nil { return line }
            guard closingAlleluia.firstMatch(in: line, range: r) != nil else { return line }
            let cut = closingAlleluia.stringByReplacingMatches(in: line, range: r, withTemplate: "")
            let kept = cut.trimmingCharacters(in: .whitespaces)
            return [".", "!", "?"].contains(where: { kept.hasSuffix($0) }) ? kept : kept + "."
        }.joined(separator: "\n")
    }

    static func seasonalAlleluia(_ p: ProperText, paschal: Bool, lenten: Bool) -> ProperText {
        func t(_ x: String) -> String {
            let y = paschalAlleluia(x, paschal: paschal)
            return lenten ? lentenAlleluia(y) : y
        }
        return ProperText(lat: t(p.lat), eng: t(p.eng), ref: p.ref)
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
