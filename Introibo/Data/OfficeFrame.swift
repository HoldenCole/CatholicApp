import Foundation

// MARK: - OfficeFrame
//
// The fixed frame of every hour as Divinum Officium prints it — everything
// around the proper texts that the templates and the rubrics left out: the
// Pater/Ave/Credo of the older books only; the opening's Sicut erat and
// Allelúja (Laus tibi from Septuagesima to Holy Week); Glória Patri after
// every psalm and canticle (Réquiem ætérnam in the Office of the Dead,
// nothing in the Triduum, none after the Benedicite); the invitatory woven
// into the Venite; ℟. Deo grátias after the capitulum; the short responsory
// said whole; Dómine, exáudi and Orémus before the collect with the
// conclusion and ℟. Amen after it; the Pater noster of Matins said secreto up
// to Et ne nos indúcas, with DO's choice of absolution and blessings; the
// ends of the little hours, Prime and Compline.
//
// Kotlin mirror: android/.../data/content/OfficeFrame.kt

/// office_conclusions.json: the collect (folded) → conclusion code table.
struct OfficeConclusions: Decodable {
    var collects: [String: String] = [:]
}

enum OfficeFrame {

    struct Ctx {
        let hourSlug: String
        let rite: MissalRite
        /// 0 = Sunday … 6 = Saturday
        let dow: Int
        let office: OfficeRubrics.Office?
        let lessons: Int
        let nocturns: Int
        /// A "Special <Hour>" script: DO's literal text, framed already.
        let special: Bool
        let template: Hour
    }

    /// The collect → conclusion table, set by ContentStore.
    static var conclusions: [String: String] = [:]
    /// The template's Pater noster / Ave María / Credo part (Lauds), set by ContentStore.
    static var paterAveCredo: Hour.Part? = nil

    private static let gloria: [Hour.Part.Verse] = [
        .init(lat: "Glória Patri, et Fílio, * et Spirítui Sancto.", eng: "Glory be to the Father, and to the Son, * and to the Holy Ghost."),
        .init(lat: "Sicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.", eng: "As it was in the beginning, is now, and ever shall be, * world without end. Amen."),
    ]
    private static let requiem: [Hour.Part.Verse] = [
        .init(lat: "Réquiem ætérnam * dona eis, Dómine.", eng: "Eternal rest * grant unto them, O Lord."),
        .init(lat: "Et lux perpétua * lúceat eis.", eng: "And let perpetual light * shine upon them."),
    ]

    private static let absolutions: [(String, String)] = [
        ("Exáudi, Dómine Jesu Christe, preces servórum tuórum, et miserére nobis: Qui cum Patre et Spíritu Sancto vivis et regnas in sǽcula sæculórum.",
         "O Lord Jesus Christ, graciously hear the prayers of Thy servants, and have mercy upon us, Who livest and reignest with the Father, and the Holy Ghost, ever world without end."),
        ("Ipsíus píetas et misericórdia nos ádjuvet, qui cum Patre et Spíritu Sancto vivit et regnat in sǽcula sæculórum.",
         "May His loving-kindness and mercy help us, Who liveth and reigneth with the Father, and the Holy Ghost, world without end."),
        ("A vínculis peccatórum nostrórum absólvat nos omnípotens et miséricors Dóminus.",
         "May the Almighty and merciful Lord loose us from the bonds of our sins."),
    ]
    private static let blessings: [[(String, String)]] = [
        [("Benedictióne perpétua benedícat nos Pater ætérnus.", "May the Eternal Father bless us with an eternal blessing."),
         ("Unigénitus Dei Fílius nos benedícere et adjuváre dignétur.", "May the Son, the Sole-begotten, mercifully bless and keep us."),
         ("Spíritus Sancti grátia illúminet sensus et corda nostra.", "May the grace of the Holy Spirit enlighten all our hearts and minds.")],
        [("Deus Pater omnípotens sit nobis propítius et clemens.", "May God the Father Omnipotent, be to us merciful and clement."),
         ("Christus perpétuæ det nobis gáudia vitæ.", "May Christ to all His people give, for ever in His sight to live."),
         ("Ignem sui amóris accéndat Deus in córdibus nostris.", "May the Spirit's fire Divine in our hearts enkindled shine.")],
        [("Ille nos benedícat, qui sine fine vivit et regnat.", "May His blessing be upon us who doth live and reign for ever."),
         ("Divínum auxílium máneat semper nobíscum.", "God's most mighty strength alway be His people's staff and stay."),
         ("Ad societátem cívium supernórum perdúcat nos Rex Angelórum.", "May He that is the Angels' King to that high realm His people bring.")],
    ]
    private static let evangelica = ("Evangélica léctio sit nobis salus et protéctio.", "May the Gospel's holy lection be our safety and protection.")
    private static let evangelica9 = ("Per evangélica dicta, deleántur nostra delícta.", "May the Gospel's glorious word cleansing to our souls afford.")
    private static let cujus: [(String, String)] = [
        ("Cujus festum cólimus, ipse intercédat pro nobis ad Dóminum.", "He whose feast-day we are keeping, be our Advocate with God."),
        ("Quorum festum cólimus, ipsi intercédant pro nobis ad Dóminum.", "They whose feast-day we are keeping, be our Advocates with God."),
        ("Cujus festum cólimus, ipsa intercédat pro nobis ad Dóminum.", "She whose feast-day we are keeping, be our Advocate with God."),
        ("Quarum festum cólimus, ipsæ intercédant pro nobis ad Dóminum.", "They whose feast-day we are keeping, be our Advocates with God."),
        ("Cujus festum cólimus, ipsa Virgo vírginum intercédat pro nobis ad Dóminum.", "She whose feast-day we are keeping, Mary, blessed Maid of Maidens, be our Advocate with God."),
        ("Cujus festum cólimus, ipse gloriósus Pater noster intercédat pro nobis ad Dóminum.", "May he whose feast-day we are keeping, our glorious Father, be our advocate with God."),
    ]

    static func apply(_ parts: [Hour.Part], _ c: Ctx) -> [Hour.Part] {
        if c.hourSlug == "office-of-the-dead" { return parts }
        var out = parts
        let dayName = c.office?.dayName ?? ""
        // the office's DO key ("quad6-5", "pasc0-0"; a saint's "12-08") — dayName is the week only
        let key = (c.office?.temporal ?? false) ? (c.office?.key.lowercased() ?? "") : ""
        let triduum = key.hasPrefix("quad6-4") || key.hasPrefix("quad6-5") || key.hasPrefix("quad6-6")
        let dead = c.office?.communeKey == "C12"
        let lentOrSept = dayName.hasPrefix("Quad")

        pater(&out, c)
        opening(&out, lentOrSept)
        closing(&out)
        if !c.special {
            invitatory(&out, dead)
            gloriaPass(&out, triduum, dead)
            capitulum(&out)
            responsoryBreve(&out)
            if c.hourSlug == "matutinum" { matins(&out, c) }
            collects(&out, c)
            switch c.hourSlug {
            case "tertia", "sexta", "nona": littleHour(&out)
            case "prima": littleHour(&out, withFidelium: false); prime(&out)
            case "completorium": compline(&out, c)
            default: break
            }
            marianTail(&out)
            if c.rite == .pre1955 { olderBooksEnd(&out, c) }
        } else {
            gloriaPass(&out, triduum, dead)
        }
        return out
    }

    // MARK: Pater noster, Ave María, Credo

    private static func pater(_ out: inout [Hour.Part], _ c: Ctx) {
        let i = out.firstIndex { $0.type == "pater" && ($0.label ?? "").hasPrefix("Pater Noster, Ave") }
        if c.rite != .pre1955 {
            if let i { out.remove(at: i) }
            return
        }
        if c.hourSlug == "completorium" { if let i { out.remove(at: i) }; return }
        let withCredo = c.hourSlug == "matutinum" || c.hourSlug == "prima"
        guard let i else {
            if c.hourSlug == "matutinum", let p = paterAveCredo { out.insert(secreto(p, withCredo), at: 0) }
            return
        }
        out[i] = secreto(out[i], withCredo)
    }

    private static func secreto(_ p: Hour.Part, _ withCredo: Bool) -> Hour.Part {
        func cut(_ t: String?) -> String? {
            guard let t else { return nil }
            if withCredo { return t }
            return t.components(separatedBy: "\n\n").prefix(2).joined(separator: "\n\n")
        }
        var q = p
        q.label = withCredo ? "Pater noster, Ave María, Credo (secréto)" : "Pater noster, Ave María (secréto)"
        q.lat = cut(p.lat); q.eng = cut(p.eng)
        return q
    }

    // MARK: Deus in adjutórium

    private static func opening(_ out: inout [Hour.Part], _ lentOrSept: Bool) {
        for i in out.indices {
            let p = out[i]
            guard p.type == "vr", (p.lat ?? "").hasPrefix("Deus, in adjutórium"), (p.latR ?? "").hasPrefix("Dómine, ad adjuvándum") else { continue }
            let lat = ["℟. Dómine, ad adjuvándum me festína.", gloria[0].lat, gloria[1].lat,
                       lentOrSept ? "Laus tibi, Dómine, Rex ætérnæ glóriæ." : "Allelúja."]
            let eng = ["℟. O Lord, make haste to help me.", gloria[0].eng, gloria[1].eng,
                       lentOrSept ? "Praise be to Thee, O Lord, King of eternal glory." : "Alleluia."]
            var q = p
            q.lat = "℣. " + (p.lat ?? ""); q.eng = p.eng.map { "℣. " + $0 }
            q.latR = lat.joined(separator: "\n"); q.engR = eng.joined(separator: "\n")
            out[i] = q
        }
    }

    // MARK: Benedicámus Dómino. ℟. Deo grátias.

    private static func twoLines(_ t: String?) -> String? {
        guard let t, !t.contains("\n") else { return t }
        let s = t.trimmingCharacters(in: .whitespaces)
        guard let m = try? NSRegularExpression(pattern: "^(.*?[.!])\\s+(.+)$").firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let r1 = Range(m.range(at: 1), in: s), let r2 = Range(m.range(at: 2), in: s) else { return t }
        return "℣. " + String(s[r1]) + "\n℟. " + String(s[r2])
    }

    private static func closing(_ out: inout [Hour.Part]) {
        for i in out.indices {
            let p = out[i]
            guard p.type == "closing", (p.lat ?? "").hasPrefix("Benedicámus Dómino. Deo grátias") else { continue }
            out[i].lat = twoLines(p.lat)
            out[i].eng = twoLines(p.eng)
        }
    }

    // MARK: Glória Patri after the psalms

    private static func hasDoxology(_ p: Hour.Part) -> Bool {
        guard let last = p.verses?.last?.lat else { return false }
        return last.hasPrefix("Sicut erat") || last.contains("Glória Patri") || last.hasPrefix("Et lux perpétua")
    }

    private static func isBenedicite(_ p: Hour.Part) -> Bool {
        (p.label ?? "").contains("Trium Puer") || (p.verses?.first?.lat ?? "").hasPrefix("Benedícite, ómnia ópera")
    }

    private static func gloriaPass(_ out: inout [Hour.Part], _ triduum: Bool, _ dead: Bool) {
        if triduum { return }
        for i in out.indices {
            let p = out[i]
            guard p.type == "psalm" || p.type == "canticle", let vs = p.verses, !vs.isEmpty else { continue }
            if p.variationKey == "matutinum.psalm1" || p.variationKey == "matutinum.canticle" || (p.label ?? "").contains("Te Deum") { continue }
            if isBenedicite(p) || hasDoxology(p) { continue }
            out[i].verses = vs + (dead ? requiem : gloria)
        }
    }

    // MARK: The invitatory inside the Venite

    private static func half(_ t: String) -> String {
        guard let r = t.range(of: "*") else { return AntiphonPlacement.whole(t) }
        return AntiphonPlacement.whole(String(t[r.upperBound...])).trimmingCharacters(in: .whitespaces)
    }

    private static func invitatory(_ out: inout [Hour.Part], _ dead: Bool) {
        guard let ai = out.firstIndex(where: { $0.type == "antiphon" && $0.variationKey == "invit" && !($0.lat ?? "").isEmpty }),
              let pi = out.firstIndex(where: { $0.type == "psalm" && $0.variationKey == "matutinum.psalm1" && !($0.verses ?? []).isEmpty }),
              let alat = out[ai].lat, let vs = out[pi].verses else { return }
        let full = "Ant. " + AntiphonPlacement.whole(alat)
        let hlf = "Ant. " + half(alat)
        let aeng = out[ai].eng ?? ""
        let efull = "Ant. " + AntiphonPlacement.whole(aeng)
        let ehalf = "Ant. " + half(aeng)
        let starts: [(String, Bool)] = [("Præoccupémus", true), ("Quia in manu", false), ("Quia ipse est", true), ("Sicut in exacerbatióne", false), ("Quibus jurávi", true)]
        if starts.filter({ s in vs.contains { $0.lat.hasPrefix(s.0) } }).count < 4 { return }
        var nv: [Hour.Part.Verse] = [.init(lat: full, eng: efull)]   // intoned, then said whole
        for v in vs {
            nv.append(v)
            if let s = starts.first(where: { v.lat.hasPrefix($0.0) }) {
                nv.append(s.1 ? .init(lat: full, eng: efull) : .init(lat: hlf, eng: ehalf))
            }
        }
        let dox = dead ? requiem : gloria
        nv.append(.init(lat: "℣. " + dox[0].lat, eng: "℣. " + dox[0].eng))
        nv.append(.init(lat: "℟. " + dox[1].lat, eng: "℟. " + dox[1].eng))
        nv.append(.init(lat: hlf, eng: ehalf))
        nv.append(.init(lat: full, eng: efull))
        out[pi].verses = nv
    }

    // MARK: Capitulum

    private static func capitulum(_ out: inout [Hour.Part]) {
        for i in out.indices {
            let p = out[i]
            guard p.type == "capitulum", let lat = p.lat, !lat.isEmpty, !lat.contains("Deo grátias") else { continue }
            out[i].lat = lat + "\n℟. Deo grátias."
            out[i].eng = p.eng.map { $0 + "\n℟. Thanks be to God." }
        }
    }

    // MARK: Short responsory

    private static func breve(_ t: String) -> String {
        var ls = t.components(separatedBy: "\n")
        guard let first = ls.first, first.hasPrefix("℟.br.") else { return t }
        if ls.count < 2 || !ls[1].hasPrefix("℟.") {
            ls.insert("℟. " + first.dropFirst("℟.br.".count).trimmingCharacters(in: .whitespaces), at: 1)
        }
        for k in ls.indices where ls[k].hasPrefix("Glória Patri") || ls[k].hasPrefix("Gloria al Padre") || ls[k].hasPrefix("Glory be") {
            ls[k] = "℣. " + ls[k]
        }
        return ls.joined(separator: "\n")
    }

    private static func responsoryBreve(_ out: inout [Hour.Part]) {
        for i in out.indices {
            let p = out[i]
            guard p.type == "responsory", let lat = p.lat, lat.hasPrefix("℟.br.") else { continue }
            out[i].lat = breve(lat)
            out[i].eng = p.eng.map(breve)
        }
    }

    // MARK: Collects

    private static let shortConclusion = "\\s*(Per Dóminum nostrum Jesum Christum\\.|Through our Lord Jesus Christ\\.|Por nuestro Señor Jesucristo\\.)\\s*(Amen|Amén)\\.\\s*$"

    /// The templates' short "Per Dóminum nostrum Jesum Christum. Amen." gives way to the whole conclusion.
    private static func unshort(_ p: Hour.Part) -> Hour.Part {
        guard let lat = p.lat, lat.range(of: shortConclusion, options: .regularExpression) != nil else { return p }
        var q = p
        q.lat = lat.replacingOccurrences(of: shortConclusion, with: "", options: .regularExpression)
        q.eng = p.eng?.replacingOccurrences(of: shortConclusion, with: "", options: .regularExpression)
        return q
    }

    private static func hasConclusion(_ lat: String) -> Bool {
        let t = lat.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasSuffix("Amen.") || t.has("Per Dóminum|Per eúndem|Qui vivis|Qui tecum|Per Christum|Per eumdem")
    }

    /// compare.norm of the QA tooling: accents, æ/œ, j/i, u/v and punctuation folded.
    static func foldKey(_ s: String) -> String {
        let d = s.decomposedStringWithCanonicalMapping.unicodeScalars.filter { !($0.properties.generalCategory == .nonspacingMark) }
        var l = String(String.UnicodeScalarView(d)).lowercased()
        l = l.replacingOccurrences(of: "æ", with: "ae").replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "j", with: "i").replacingOccurrences(of: "v", with: "u")
        l = l.replacingOccurrences(of: "[^a-z0-9 ]+", with: " ", options: .regularExpression)
        return l.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    private static func conclusionCode(_ lat: String) -> String {
        if let c = conclusions[foldKey(lat)] { return c }
        let e = lat.has("Spíritu[sm]? Sanct") ? "e" : ""
        if lat.has("(^|[,.:;] )(Dómine Jesu Christe|Jesu Christe|Dómine Jesu)|Qui vivis|Qui cum Patre") { return "QV" + e }
        if lat.has("Fíli[ui]|Unigénit|Jesum Christum|Jesu Christi|Christ[oiu]m?\\b|Dómin[iu]m? nostr[iu]m?|Redemptór|Salvatór") { return "PE" + e }
        return "PD" + e
    }

    private static func conclusionText(_ code: String) -> (String, String) {
        let e = code.hasSuffix("e")
        let spLat = e ? "ejúsdem Spíritus Sancti" : "Spíritus Sancti"
        let spEng = e ? "the same Holy Ghost" : "the Holy Ghost"
        let base = e ? String(code.dropLast()) : code
        switch base {
        case "PE": return ("Per eúndem Dóminum nostrum Jesum Christum Fílium tuum, qui tecum vivit et regnat in unitáte \(spLat), Deus, per ómnia sǽcula sæculórum.",
                           "Through the same Jesus Christ, thy Son, our Lord, Who liveth and reigneth with thee, in the unity of \(spEng), God, world without end.")
        case "QV": return ("Qui vivis et regnas cum Deo Patre, in unitáte \(spLat), Deus, per ómnia sǽcula sæculórum.",
                           "Who livest and reignest with God the Father, in the unity of \(spEng), God, world without end.")
        case "QT": return ("Qui tecum vivit et regnat in unitáte \(spLat), Deus, per ómnia sǽcula sæculórum.",
                           "Who with thee liveth and reigneth in the unity of \(spEng), God, world without end.")
        case "PC": return ("Per Christum Dóminum nostrum.", "Through Christ our Lord.")
        default: return ("Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et regnat in unitáte \(spLat), Deus, per ómnia sǽcula sæculórum.",
                         "Through Jesus Christ, thy Son our Lord, Who liveth and reigneth with thee, in the unity of \(spEng), God, world without end.")
        }
    }

    private static func oremus() -> Hour.Part { var p = Hour.Part(type: "heading"); p.label = "Orémus."; return p }
    private static func vr(_ label: String, _ lat: String, _ latR: String, _ eng: String, _ engR: String) -> Hour.Part {
        var p = Hour.Part(type: "vr"); p.label = label; p.lat = lat; p.latR = latR; p.eng = eng; p.engR = engR; return p
    }
    private static func domineExaudi() -> Hour.Part {
        vr("Versus", "℣. Dómine, exáudi oratiónem meam.", "℟. Et clamor meus ad te véniat.", "℣. O Lord, hear my prayer.", "℟. And let my cry come unto Thee.")
    }

    private static let mainCollects: Set<String> = ["oratio", "oratio_prima", "oratio_completorium"]

    private static func withConclusion(_ p: Hour.Part) -> Hour.Part {
        guard let lat = p.lat else { return p }
        let (cl, ce) = conclusionText(conclusionCode(lat))
        var q = p
        q.lat = lat + "\n" + cl + "\n℟. Amen."
        q.eng = p.eng.map { $0 + "\n" + ce + "\n℟. Amen." }
        return q
    }

    private static func collects(_ out: inout [Hour.Part], _ c: Ctx) {
        var i = 0
        while i < out.count {
            if out[i].type == "collect" { out[i] = unshort(out[i]) }
            let p = out[i]
            guard p.type == "collect", let lat = p.lat, !lat.isEmpty, p.variationKey != "prima2.sanctamaria" else { i += 1; continue }
            let vk = p.variationKey
            let main = vk != nil && mainCollects.contains(vk!)
            let commem = vk == nil && (p.label == "Oratio" || p.label == "Orémus")
            if main {
                let prev = out[..<i].last { $0.type != "heading" }
                if prev?.type != "preces" && !(prev?.lat ?? "").hasPrefix("℣. Dómine, exáudi") { out.insert(domineExaudi(), at: i); i += 1 }
            }
            if !lat.hasPrefix("Orémus") && (i == 0 || out[i - 1].label != "Orémus.") { out.insert(oremus(), at: i); i += 1 }
            if main || commem {
                var j = i + 1
                var lastOfRun = true
                while !main && j < out.count {
                    let q = out[j]
                    if q.type == "collect" && q.variationKey == nil && (q.label == "Oratio" || q.label == "Orémus") { lastOfRun = false; break }
                    if q.type == "heading" || q.type == "antiphon" || q.type == "vr" { j += 1; continue }
                    break
                }
                if lastOfRun && !hasConclusion(lat) { out[i] = withConclusion(p) }
            } else if !hasConclusion(lat) && vk != nil {
                out[i] = withConclusion(p)
            }
            i += 1
        }
    }

    // MARK: Matins: the Pater noster secreto, the absolution and blessings

    private static func before(_ t: String, _ marks: [String]) -> String {
        var s = t
        for m in marks { if let r = s.range(of: m) { s = String(s[..<r.lowerBound]) } }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func paterSecreto(_ p: Hour.Part) -> Hour.Part {
        let lat = (p.lat ?? "").components(separatedBy: "\n\n").first ?? ""
        let eng = (p.eng ?? "").components(separatedBy: "\n\n").first ?? ""
        let latCut = before(lat, [" Et ne nos", "\n℣. Et ne nos"])
        let engCut = before(eng, [" And lead us not", "\n℣. And lead us not"])
        var q = p
        q.label = "Pater noster (secréto)"
        q.lat = latCut + "\n℣. Et ne nos indúcas in tentatiónem.\n℟. Sed líbera nos a malo."
        q.eng = engCut.isEmpty ? p.eng : engCut + "\n℣. And lead us not into temptation.\n℟. But deliver us from evil."
        return q
    }

    private static func matins(_ out: inout [Hour.Part], _ c: Ctx) {
        var i = 0
        while i < out.count {
            let p = out[i]
            if p.type == "pater" && (p.label ?? "") == "Pater Noster" {
                if i + 1 < out.count, out[i + 1].type == "collect" { out.remove(at: i); continue }
                out[i] = paterSecreto(p)
            }
            i += 1
        }
        guard let o = c.office else { return }
        // the last responsory of each nocturn ends with ℣. Glória Patri and the repeat
        // (not in Passiontide unless a saint's office; Réquiem in the Office of the Dead)
        let passion = o.dayName.has("^Quad[56]") && !o.sanctoral && !o.ruleHas("Gloria responsory")
        let dead = o.communeKey == "C12"
        let gl = dead ? "℣. Réquiem ætérnam dona eis, Dómine, * et lux perpétua lúceat eis." : "℣. Glória Patri, et Fílio, * et Spirítui Sancto."
        let ge = dead ? "℣. Eternal rest grant unto them, O Lord, * and let perpetual light shine upon them." : "℣. Glory be to the Father, and to the Son, * and to the Holy Ghost."
        let gloriaLine = "^(℣\\.|V\\.)?\\s*(Glória Patri|Glory be|Gloria al Padre|Réquiem ætérnam|Eternal rest|Descanso eterno)"
        func isGloria(_ l: String) -> Bool { l.range(of: gloriaLine, options: .regularExpression) != nil }
        for i in out.indices {
            let p = out[i]
            guard p.type == "responsory" else { continue }
            let next: Hour.Part? = i + 1 < out.count ? out[i + 1] : nil
            // the responsory closes a nocturn when a new nocturn, the collect or the end follows (the Te Deum replaces the last one)
            // (DO responsory_gloria: also the responsory before the last lesson when the Te Deum follows it)
            let teDeumIdx = out.firstIndex { $0.type == "canticle" && ($0.label ?? "").contains("Te Deum") } ?? -1
            let beforeTeDeum = teDeumIdx > i && !out[(i + 1)..<teDeumIdx].contains { $0.type == "responsory" }
            let last = next == nil || next!.type == "heading" || next!.type == "collect" || (next!.type == "vr" && (next!.lat ?? "").hasPrefix("℣. Dómine, exáudi")) || beforeTeDeum
            let wants = last && !passion
            if p.v1Lat != nil, let r2 = p.r2Lat {
                if wants && !isGloria(r2) {
                    out[i].r2Lat = r2 + "\n" + gl + "\n" + r2
                    out[i].r2Eng = p.r2Eng.map { "\($0)\n\(ge)\n\($0)" }
                }
                continue
            }
            guard let lat = p.lat else { continue }
            // the lat form: drop a doxology (the assets carry the whole Glória Patri with its Sicut erat) and re-add DO's half form where it belongs
            func strip(_ t: String) -> [String] {
                var ls = t.components(separatedBy: "\n")
                if let g = ls.firstIndex(where: isGloria) { ls.remove(at: g); if g < ls.count { ls.remove(at: g) } }
                return ls
            }
            let ll = strip(lat); let el = p.eng.map(strip)
            let changed = ll.count != lat.components(separatedBy: "\n").count
            if !wants {
                if changed { out[i].lat = ll.joined(separator: "\n"); out[i].eng = el?.joined(separator: "\n") }
                continue
            }
            guard let rep = ll.last(where: { $0.hasPrefix("R. ") || $0.hasPrefix("℟. ") }) else { continue }
            let erep = el?.last(where: { $0.hasPrefix("R. ") || $0.hasPrefix("℟. ") })
            out[i].lat = (ll + [gl, rep]).joined(separator: "\n")
            if var e = el {
                e.append(ge)
                if let er = erep { e.append(er) }
                out[i].eng = e.joined(separator: "\n")
            }
        }
        var english: [String: String] = [:]
        for p in c.template.parts where p.type == "vr" { if let l = p.lat, let e = p.eng { english[l] = e } }
        for (l, e) in absolutions where english[l] == nil { english[l] = e }
        for set in blessings { for (l, e) in set where english[l] == nil { english[l] = e } }
        if english[evangelica.0] == nil { english[evangelica.0] = evangelica.1 }
        if english[evangelica9.0] == nil { english[evangelica9.0] = evangelica9.1 }
        for (l, e) in cujus where english[l] == nil { english[l] = e }

        let sancti = (o.sanctoral && o.rankLine.has("\\b(Ss?|Bb?)\\.", ci: true)) || o.communeKey == "C11"
        let key = o.temporal ? o.key.lowercased() : ""
        let homilyFirst = o.rankLine.has("vigil|quatt|ciner", ci: true)
            || key.has("^quad[1-5]-[1-6]|^quad6-1|^pasc5-1|^pasc0|^pasc7")
            || (key.has("^nat(29|3[01])") && c.rite != .rite1962)
        let absIdx = out.indices.filter { out[$0].type == "vr" && out[$0].label == "Absolutio" }
        let blIdx = out.indices.filter { out[$0].type == "vr" && (out[$0].label ?? "").hasPrefix("Blessing before") }
        func set(_ i: Int, _ text: (String, String)) {
            out[i].lat = text.0
            out[i].eng = english[text.0] ?? text.1
        }
        if c.lessons >= 9 && absIdx.count == 3 && blIdx.count == 9 {
            if sancti { set(blIdx[7], cujus[cujusQ(o)]) }
            return
        }
        guard absIdx.count == 1, blIdx.count == 3 else { return }
        var k = c.dow == 0 ? 1 : c.dow
        if k > 3 { k -= 3 }
        var ben: [(String, String)]
        if homilyFirst { ben = blessings[2]; ben[0] = evangelica }
        else if o.isSunday { ben = blessings[2]; ben[2] = evangelica9 }
        else if sancti { ben = blessings[2]; ben[1] = cujus[cujusQ(o)] }
        else { ben = blessings[k - 1] }
        set(absIdx[0], absolutions[k - 1])
        for n in 0..<3 { set(blIdx[n], ben[n]) }
    }

    /// DO's cujus_q: which "Cujus festum cólimus" fits the office.
    private static func cujusQ(_ o: OfficeRubrics.Office) -> Int {
        if o.ruleHas("Quorum Festum") { return 1 }
        if o.communeKey == "C11" || o.key.has("08-15|09-08|12-08") { return 4 }
        let r = o.rankLine
        if r.has("S\\. P\\. N\\. Benedicti Abbatis") { return 5 }
        var j = 0
        if r.has("virgin|vidu[aæ]|poenitentis|pœnitentis|C6|C7", ci: true) && !r.has("C[2-5]") { j += 2 }
        if r.has("ss\\.|bb\\.|sanctorum|sociorum", ci: true) { j += 1 }
        return j
    }

    // MARK: The ends of the hours

    private static func fidelium() -> Hour.Part {
        vr("Versus", "℣. Fidélium ánimæ per misericórdiam Dei requiéscant in pace.", "℟. Amen.",
           "℣. May the souls of the faithful, through the mercy of God, rest in peace.", "℟. Amen.")
    }

    private static func littleHour(_ out: inout [Hour.Part], withFidelium: Bool = true) {
        guard var ci = out.firstIndex(where: { $0.type == "closing" && ($0.lat ?? "").contains("Benedicámus Dómino") }) else { return }
        // ℣. Dómine, exáudi before the Benedicámus
        if ci == 0 || !(out[ci - 1].lat ?? "").hasPrefix("℣. Dómine, exáudi") { out.insert(domineExaudi(), at: ci); ci += 1 }
        if !withFidelium || out[(ci + 1)...].contains(where: { ($0.lat ?? "").contains("Fidélium ánimæ") }) { return }
        out.insert(fidelium(), at: ci + 1)
    }

    /// ℣. Divínum auxílium after the Marian antiphon's prayer (Compline; Lauds in the older books).
    private static func marianTail(_ out: inout [Hour.Part]) {
        guard let mi = out.firstIndex(where: { $0.type == "marian" }),
              !out.contains(where: { ($0.lat ?? "").hasPrefix("℣. Divínum auxílium") }) else { return }
        let v = vr("Versus", "℣. Divínum auxílium ✠ máneat semper nobíscum.", "℟. Amen.",
                   "℣. May the divine assistance ✠ remain always with us.", "℟. Amen.")
        if let oi = out.lastIndex(where: { $0.type == "collect" && ($0.variationKey ?? "").hasPrefix("completorium.marian") }), oi > mi {
            out.insert(v, at: oi + 1)
        } else {
            out.append(v)
        }
    }

    /// The older books: the Pater noster (secreto) after every hour; at Lauds ℣. Dóminus det nobis before the Marian antiphon.
    private static func olderBooksEnd(_ out: inout [Hour.Part], _ c: Ctx) {
        if c.hourSlug == "completorium" { return }
        guard let pater = paterAveCredo,
              let fi = out.lastIndex(where: { ($0.lat ?? "").contains("idélium ánimæ") }),
              !out[(fi + 1)...].contains(where: { $0.type == "pater" }) else { return }
        var p = Hour.Part(type: "pater"); p.label = "Pater noster (secréto)"
        p.lat = pater.lat?.components(separatedBy: "\n\n").first
        p.eng = pater.eng?.components(separatedBy: "\n\n").first
        var adds = [p]
        if c.hourSlug == "laudes", out[(fi + 1)...].contains(where: { $0.type == "marian" }) {
            adds.append(vr("Versus", "℣. Dóminus det nobis suam pacem.", "℟. Et vitam ætérnam. Amen.",
                           "℣. May the Lord grant us his peace.", "℟. And life everlasting. Amen."))
        }
        out.insert(contentsOf: adds, at: fi + 1)
    }

    private static func prime(_ out: inout [Hour.Part]) {
        guard let bi = out.firstIndex(where: { $0.variationKey == "prima2.benedictio2" }) else { return }
        func merge(_ t: String?) -> String? {
            guard let t else { return nil }
            let ls = t.components(separatedBy: "\n")
            if ls.count < 4 { return t }
            let fid = ls[2].hasPrefix("℣.") ? String(ls[2].dropFirst(2)) : ls[2]
            return ls[0].trimmingCharacters(in: .whitespaces) + " " + fid.trimmingCharacters(in: .whitespaces) + "\n" + ls[1]
        }
        out[bi].lat = merge(out[bi].lat)
        out[bi].eng = merge(out[bi].eng)
        if bi == 0 || !(out[bi - 1].lat ?? "").hasPrefix("℣. Benedícite") {
            out.insert(vr("Versus", "℣. Benedícite.", "℟. Deus.", "℣. Pray, Lord, a blessing.", "℟. God."), at: bi)
        }
    }

    private static func compline(_ out: inout [Hour.Part], _ c: Ctx) {
        let pater = paterAveCredo
        if let ri = out.firstIndex(where: { $0.type == "vr" && ($0.label ?? "").hasPrefix("Short Reading") }),
           !(ri + 1 < out.count && (out[ri + 1].lat ?? "").hasPrefix("℣. Adjutórium")) {
            var adds: [Hour.Part] = [vr("Versus", "℣. Adjutórium nostrum ✠ in nómine Dómini.", "℟. Qui fecit cælum et terram.",
                                         "℣. Our help ✠ is in the name of the Lord.", "℟. Who made heaven and earth.")]
            if let pater {
                var p = Hour.Part(type: "pater"); p.label = "Pater noster (secréto)"
                p.lat = pater.lat?.components(separatedBy: "\n\n").first
                p.eng = pater.eng?.components(separatedBy: "\n\n").first
                adds.append(p)
            }
            out.insert(contentsOf: adds, at: ri + 1)
        }
        if let mi = out.firstIndex(where: { $0.type == "marian" }),
           !(mi > 0 && (out[mi - 1].lat ?? "").hasPrefix("Benedíctio. Benedícat")) {
            out.insert(contentsOf: [
                domineExaudi(),
                vr("Versus", "℣. Benedicámus Dómino.", "℟. Deo grátias.", "℣. Let us bless the Lord.", "℟. Thanks be to God."),
                vr("Benedíctio", "Benedíctio. Benedícat et custódiat nos omnípotens et miséricors Dóminus, ✠ Pater, et Fílius, et Spíritus Sanctus.", "℟. Amen.",
                   "Blessing. May the almighty and merciful Lord, ✠ the Father, the Son and the Holy Ghost, bless and keep us.", "℟. Amen."),
            ], at: mi)
        }
        // the older books add the Pater, Ave and Credo secreto after the Marian antiphon (marianTail adds Divínum auxílium)
        if c.rite == .pre1955, let pater, !out.contains(where: { ($0.label ?? "").contains("Credo (secréto)") }) {
            var p = pater; p.label = "Pater noster, Ave María, Credo (secréto)"; out.append(p)
        }
    }
}
