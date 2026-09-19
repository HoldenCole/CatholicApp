import Foundation

// The rubrics of the Roman Office as Divinum Officium applies them, ported
// line for line from android/.../OfficeRubrics.kt (which mirrors DO's Perl:
// psalmi_minor, psalmi_major, psalmi_matutinum, capitulum_minor/major,
// hymnusmajor/matutinum, invitatorium, concurrence, preces, tedeum_required,
// getcommemoratio, checksuffragium ...). Keep the two in step.

// MARK: - Asset types (office_*.json)

/// One office file's rank line and Rule, per rite (office_rules.json).
struct OfficeRule: Decodable {
    var rankName: String? = nil
    var rankLine: String? = nil
    var rank: Double? = nil
    var communeType: String? = nil
    var commune: String? = nil
    var rule: String? = nil
}

/// One line of a Divinum Officium psalm list: an antiphon with its psalms,
/// or a ℣/℟ pair (office_psalterium.json, office_ants.json, office_commune.json).
struct PsalmiLine: Decodable {
    var name: String? = nil
    var ant: String? = nil
    var antEng: String? = nil
    var psalms: [String]? = nil
    var v: String? = nil
    var r: String? = nil
    var vEng: String? = nil
    var rEng: String? = nil
}

/// DO's precedence for one hour of one day (office_ordo_<rite>.json).
struct DoOffice: Decodable {
    var w: String
    var r: Double? = nil
    var d: String? = nil
    var n: String? = nil
    var c: String? = nil
    var t: String? = nil
    var ls: Int? = nil
    var dx: Int? = nil
    var vs: Int? = nil
    var cv: String? = nil
    var cm: [String]? = nil
    var cm1: [String]? = nil
    var md: String? = nil
    var ac: [PsalmiLine]? = nil
    var ac5: String? = nil
    var hy: Int? = nil
    var tv: String? = nil
    var ov: Int? = nil
    var qt: Bool? = nil
    var co: String? = nil
}

struct DoOrdoDay: Decodable {
    var l: DoOffice? = nil
    var v: DoOffice? = nil
    var m0: String? = nil
    var m1: String? = nil
}

/// Parts keyed by DO section name, plus antiphon/psalm lists.
struct OfficePsalterium: Decodable {
    var parts: [String: Hour.Part] = [:]
    var psalmi: [String: [PsalmiLine]] = [:]

    init() {}
    init(parts: [String: Hour.Part], psalmi: [String: [PsalmiLine]]) {
        self.parts = parts
        self.psalmi = psalmi
    }
    private enum CodingKeys: String, CodingKey { case parts, psalmi }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        parts = try c.decodeIfPresent([String: Hour.Part].self, forKey: .parts) ?? [:]
        psalmi = try c.decodeIfPresent([String: [PsalmiLine]].self, forKey: .psalmi) ?? [:]
    }
}

// MARK: - A calendar date without a time (java.time.LocalDate)

struct LDate: Hashable {
    let year: Int
    let month: Int
    let day: Int

    static func from(_ d: Date) -> LDate {
        let cs = Calendar.liturgical.dateComponents([.year, .month, .day], from: d)
        return LDate(year: cs.year ?? 2000, month: cs.month ?? 1, day: cs.day ?? 1)
    }
    var date: Date {
        Calendar.liturgical.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }
    func plusDays(_ n: Int) -> LDate {
        LDate.from(Calendar.liturgical.date(byAdding: .day, value: n, to: date) ?? date)
    }
    /// 0 = Sunday … 6 = Saturday.
    var dow: Int { Calendar.liturgical.component(.weekday, from: date) - 1 }
    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var mmdd: String { String(format: "%02d-%02d", month, day) }
}

// MARK: - Regex and string helpers (the Kotlin Regex idioms)

private final class RegexCache {
    static let shared = RegexCache()
    private var cache: [String: NSRegularExpression] = [:]
    private let lock = NSLock()
    func get(_ pattern: String, ci: Bool) -> NSRegularExpression {
        let key = (ci ? "i:" : "c:") + pattern
        lock.lock(); defer { lock.unlock() }
        if let r = cache[key] { return r }
        let r = (try? NSRegularExpression(pattern: pattern, options: ci ? [.caseInsensitive] : []))
            ?? (try! NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: pattern), options: []))
        cache[key] = r
        return r
    }
}

extension String {
    var ns: NSString { self as NSString }
    var full: NSRange { NSRange(location: 0, length: ns.length) }

    /// Regex.containsMatchIn
    func has(_ pattern: String, ci: Bool = false) -> Bool {
        RegexCache.shared.get(pattern, ci: ci).firstMatch(in: self, range: full) != nil
    }
    /// Regex.matches (the whole string)
    func matchesWhole(_ pattern: String, ci: Bool = false) -> Bool {
        has("^(?:" + pattern + ")$", ci: ci)
    }
    /// Regex.find(...)?.groupValues: group 0 is the match; a missing group is "".
    func rmatch(_ pattern: String, ci: Bool = false) -> [String]? {
        guard let m = RegexCache.shared.get(pattern, ci: ci).firstMatch(in: self, range: full) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
    /// Regex.replace with a template ($1 …).
    func rreplace(_ pattern: String, _ template: String, ci: Bool = false) -> String {
        RegexCache.shared.get(pattern, ci: ci).stringByReplacingMatches(in: self, range: full, withTemplate: template)
    }
    /// Regex.replace with a closure over the groups.
    func rreplace(_ pattern: String, ci: Bool = false, _ f: ([String]) -> String) -> String {
        let re = RegexCache.shared.get(pattern, ci: ci)
        var out = ""
        var last = 0
        for m in re.matches(in: self, range: full) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let groups = (0..<m.numberOfRanges).map { i -> String in
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            out += f(groups)
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }
    /// String.split(Regex)
    func rsplit(_ pattern: String) -> [String] {
        let re = RegexCache.shared.get(pattern, ci: false)
        var out: [String] = []
        var last = 0
        for m in re.matches(in: self, range: full) {
            out.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            last = m.range.location + m.range.length
        }
        out.append(ns.substring(from: last))
        return out
    }
    func before(_ sep: String) -> String {
        guard let r = range(of: sep) else { return self }
        return String(self[..<r.lowerBound])
    }
    func after(_ sep: String) -> String {
        guard let r = range(of: sep) else { return self }
        return String(self[r.upperBound...])
    }
    func afterLast(_ sep: String) -> String {
        guard let r = range(of: sep, options: .backwards) else { return self }
        return String(self[r.upperBound...])
    }
    func dropPrefix(_ p: String) -> String { hasPrefix(p) ? String(dropFirst(p.count)) : self }
    func dropSuffix(_ s: String) -> String { hasSuffix(s) ? String(dropLast(s.count)) : self }
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
    var blankToNil: String? { isBlank ? nil : self }
    func take(_ n: Int) -> String { String(prefix(n)) }
    func takeLast(_ n: Int) -> String { String(suffix(n)) }
    var lines: [String] { components(separatedBy: "\n") }
    func containsCI(_ s: String) -> Bool { range(of: s, options: .caseInsensitive) != nil }
    func trimEnd(_ chars: String) -> String {
        var s = Substring(self)
        while let last = s.last, chars.contains(last) { s = s.dropLast() }
        return String(s)
    }
    func trimChars(_ chars: String) -> String {
        var s = Substring(self)
        while let f = s.first, chars.contains(f) { s = s.dropFirst() }
        while let l = s.last, chars.contains(l) { s = s.dropLast() }
        return String(s)
    }
}

extension Optional where Wrapped == String {
    var isNullOrBlank: Bool { self?.isBlank ?? true }
    var isNullOrEmpty: Bool { self?.isEmpty ?? true }
    var orEmpty: String { self ?? "" }
}

extension Hour.Part {
    /// Kotlin `copy(type = …)`: the same part with another type (type is immutable).
    func withType(_ t: String) -> Hour.Part {
        var n = Hour.Part(type: t)
        n.label = label; n.title = title; n.ref = ref; n.lat = lat; n.eng = eng
        n.latR = latR; n.engR = engR
        n.v1Lat = v1Lat; n.v1Eng = v1Eng; n.r1Lat = r1Lat; n.r1Eng = r1Eng
        n.v2Lat = v2Lat; n.v2Eng = v2Eng; n.r2Lat = r2Lat; n.r2Eng = r2Eng
        n.verses = verses; n.season = season; n.engBody = engBody
        n.variationKey = variationKey; n.antiphonLat = antiphonLat; n.antiphonEng = antiphonEng
        return n
    }
}

// MARK: - The resolver

final class OfficeRubrics {

    private let rules: [String: [String: OfficeRule]]
    private let psalterium: OfficePsalterium
    private let ants: [String: [String: [PsalmiLine]]]
    private let communes: [String: OfficePsalterium]
    /// DO-resolved Office sections of every proper, per rite (office_propers_<rite>.json).
    private let propersFor: (MissalRite) -> [String: OfficePsalterium]
    /// DO's precedence per date (office_ordo_<rite>.json), nil outside the bundled years.
    private let ordoFor: (MissalRite, LDate) -> DoOrdoDay?
    private let temporalPropers: [String: [String: Hour.Part]]
    private let sanctoralPropers: [String: [String: Hour.Part]]
    private let saintCommune: [String: String]
    private let saintOfficeInherit: [String: String]

    init(rules: [String: [String: OfficeRule]],
         psalterium: OfficePsalterium,
         ants: [String: [String: [PsalmiLine]]],
         communes: [String: OfficePsalterium],
         propersFor: @escaping (MissalRite) -> [String: OfficePsalterium],
         ordoFor: @escaping (MissalRite, LDate) -> DoOrdoDay?,
         temporalPropers: [String: [String: Hour.Part]],
         sanctoralPropers: [String: [String: Hour.Part]],
         saintCommune: [String: String],
         saintOfficeInherit: [String: String]) {
        self.rules = rules
        self.psalterium = psalterium
        self.ants = ants
        self.communes = communes
        self.propersFor = propersFor
        self.ordoFor = ordoFor
        self.temporalPropers = temporalPropers
        self.sanctoralPropers = sanctoralPropers
        self.saintCommune = saintCommune
        self.saintOfficeInherit = saintOfficeInherit
    }

    /// A source of office texts: a proper (raw app keys) or a commune (DO
    /// section names), with its DO antiphon lists when known.
    struct Src {
        let parts: [String: Hour.Part]
        let doKeyed: Bool
        let psalmi: [String: [PsalmiLine]]?

        func sec(_ name: String) -> Hour.Part? {
            doKeyed ? parts[name] : parts[name.lowercased().replacingOccurrences(of: " ", with: "_")]
        }
        var rule: String { parts["Rule"]?.lat ?? "" }
    }

    /// An office (the day's winner, or the one Vespers belongs to).
    final class Office {
        let sanctoral: Bool
        let key: String
        let rank: Double
        let rankLine: String
        let rule: String
        let communeType: String?
        let communeKey: String?
        let communeRule: String
        let communeRuleAny: String
        let proper: Src
        let commune: Src?
        let temporalKey: String?
        let dayName: String
        let name: String
        let date: LDate
        let rite: MissalRite
        let laudesDO: Int?
        let duplexDO: Int?
        let commemorations: [String]
        let commemorations1: [String]
        let mdKey: String?
        let anteCapitulum: [PsalmiLine]?
        let anteCapitulum5: String?
        let hymnShift: Int
        let transferVigil: String?
        let octVespera: Int
        let emberSept: Bool
        let commemoratioKey: String?

        init(sanctoral: Bool, key: String, rank: Double, rankLine: String, rule: String,
             communeType: String?, communeKey: String?, communeRule: String, communeRuleAny: String,
             proper: Src, commune: Src?, temporalKey: String?, dayName: String, name: String,
             date: LDate, rite: MissalRite, laudesDO: Int? = nil, duplexDO: Int? = nil,
             commemorations: [String] = [], commemorations1: [String] = [], mdKey: String? = nil,
             anteCapitulum: [PsalmiLine]? = nil, anteCapitulum5: String? = nil, hymnShift: Int = 0,
             transferVigil: String? = nil, octVespera: Int = 0, emberSept: Bool = false, commemoratioKey: String? = nil) {
            self.sanctoral = sanctoral; self.key = key; self.rank = rank; self.rankLine = rankLine; self.rule = rule
            self.communeType = communeType; self.communeKey = communeKey; self.communeRule = communeRule
            self.communeRuleAny = communeRuleAny; self.proper = proper; self.commune = commune
            self.temporalKey = temporalKey; self.dayName = dayName; self.name = name; self.date = date; self.rite = rite
            self.laudesDO = laudesDO; self.duplexDO = duplexDO; self.commemorations = commemorations
            self.commemorations1 = commemorations1; self.mdKey = mdKey; self.anteCapitulum = anteCapitulum
            self.anteCapitulum5 = anteCapitulum5; self.hymnShift = hymnShift; self.transferVigil = transferVigil
            self.octVespera = octVespera; self.emberSept = emberSept; self.commemoratioKey = commemoratioKey
        }

        /// "sancti:01-14" / "tempora:adv2-1": the office as a DO key.
        var keyRef: String { (sanctoral ? "sancti:" : "tempora:") + key }
        func rankHas(_ re: String) -> Bool { rankLine.has(re, ci: true) }
        func ruleHas(_ re: String) -> Bool { rule.has(re, ci: true) }
        func communeRuleHas(_ re: String) -> Bool { communeRule.has(re, ci: true) }
        func communeRuleAnyHas(_ re: String) -> Bool { communeRuleAny.has(re, ci: true) }
        var isSunday: Bool { rankHas("Dominica") }
        var temporal: Bool { !sanctoral }
        /// DO $duplex: 1 simplex/feria, 2 semiduplex, 3 duplex and above.
        var duplex: Int {
            if let d = duplexDO { return d }
            if !rankHas("duplex") { return 1 }
            if rankHas("semiduplex") { return 2 }
            return 3
        }
        var isC10: Bool { communeKey == "C10" || key.hasPrefix("bvm-sab") }
    }

    final class Resolution {
        let overrides: [String: Hour.Part]
        let drop: Set<String>
        let office: Office
        let vespera: Int
        let nocturns: Int
        let lessons: Int
        let teDeum: Bool
        let precesFeriales: Bool
        let precesDominicales: Bool
        let commemoration: Office?
        let commemorationVespera: Int
        let laudes: Int
        let marianOverride: String?
        let commemorations: [String]
        let fromDO: Bool
        /// "Omit ... Incipit": no Pater/Ave and no Deus in adjutorium.
        let omitIncipit: Bool
        /// "Omit ... Conclusion": the hour ends with the collect.
        let omitConclusion: Bool
        /// "Special Conclusio": the office's own ending (Requiem æternam).
        let conclusio: [Hour.Part]?
        /// A "Special <Hour>" script: the whole hour as DO renders it.
        let special: [Hour.Part]?
        /// Parts added after the hour (the Litany of the Saints).
        let append: [Hour.Part]
        /// The preces of Prime, the little hours and Compline (older books).
        let preces: [Hour.Part]?
        /// The suffrage of the saints before the conclusion (Divino Afflatu).
        let beforeConclusion: [Hour.Part]
        /// Parts said before the collect (the Triduum's Miserere in the older books).
        let beforeCollect: [Hour.Part]
        /// The Marian antiphon after Lauds (the Divino Afflatu books).
        let marianAfterLauds: Bool

        init(overrides: [String: Hour.Part], drop: Set<String>, office: Office, vespera: Int, nocturns: Int, lessons: Int,
             teDeum: Bool, precesFeriales: Bool, precesDominicales: Bool, commemoration: Office?, commemorationVespera: Int,
             laudes: Int, marianOverride: String?, commemorations: [String], fromDO: Bool, omitIncipit: Bool,
             omitConclusion: Bool, conclusio: [Hour.Part]?, special: [Hour.Part]?, append: [Hour.Part], preces: [Hour.Part]?,
             beforeConclusion: [Hour.Part], beforeCollect: [Hour.Part], marianAfterLauds: Bool) {
            self.overrides = overrides; self.drop = drop; self.office = office; self.vespera = vespera
            self.nocturns = nocturns; self.lessons = lessons; self.teDeum = teDeum; self.precesFeriales = precesFeriales
            self.precesDominicales = precesDominicales; self.commemoration = commemoration
            self.commemorationVespera = commemorationVespera; self.laudes = laudes; self.marianOverride = marianOverride
            self.commemorations = commemorations; self.fromDO = fromDO; self.omitIncipit = omitIncipit
            self.omitConclusion = omitConclusion; self.conclusio = conclusio; self.special = special; self.append = append
            self.preces = preces; self.beforeConclusion = beforeConclusion; self.beforeCollect = beforeCollect
            self.marianAfterLauds = marianAfterLauds
        }
    }

    private struct AntLine {
        let ant: String?
        let antEng: String?
        let psalms: [String]?
    }

    // MARK: helpers

    private func riteRules(_ rite: MissalRite) -> [String: OfficeRule] { rules[rite.rawValue] ?? [:] }

    private func lines(_ p: Hour.Part?) -> [String] {
        (p?.lat ?? "").lines.map { $0.trimmed }.filter { !$0.isEmpty }
    }
    private func engLines(_ p: Hour.Part?) -> [String] {
        (p?.eng ?? "").lines.map { $0.trimmed }.filter { !$0.isEmpty }
    }

    /// DO psalm-list lines, ℣/℟ pairs expanded to two lines (DO's 15-line
    /// Matins layout: 3 antiphons, ℣, ℟ per nocturn).
    private func expand(_ l: [PsalmiLine]) -> [AntLine] {
        var out: [AntLine] = []
        for x in l {
            if let v = x.v {
                out.append(AntLine(ant: v, antEng: x.vEng, psalms: nil))
                out.append(AntLine(ant: x.r, antEng: x.rEng, psalms: nil))
            } else {
                out.append(AntLine(ant: x.ant, antEng: x.antEng, psalms: x.psalms))
            }
        }
        return out
    }

    /// An antiphon list of a source: DO's own list when the source is
    /// known to DO (then a missing section is genuinely absent), else the
    /// proper's multi-line part.
    private func antList(_ src: Src?, _ name: String) -> [AntLine]? {
        guard let src else { return nil }
        if let ps = src.psalmi { return ps[name].map { expand($0) } }
        guard let p = src.sec(name) else { return nil }
        let ls = lines(p)
        if ls.isEmpty { return nil }
        let es = engLines(p)
        return ls.enumerated().map { i, s in AntLine(ant: s, antEng: i < es.count ? es[i] : nil, psalms: nil) }
    }

    private func hasSection(_ src: Src?, _ name: String) -> Bool {
        guard let src else { return false }
        if let ps = src.psalmi, name.hasPrefix("Ant ") {
            return ps[name] != nil || (src.sec(name) != nil && !name.hasPrefix("Ant Laudes") && !name.hasPrefix("Ant Vespera") && !name.hasPrefix("Ant Matutinum"))
        }
        return src.sec(name) != nil
    }

    /// A single antiphon section ("Ant 1", "Ant Tertia", "Invit").
    private func antSec(_ src: Src?, _ name: String) -> Hour.Part? {
        guard let src else { return nil }
        if name.hasPrefix("Ant ") && !["Ant 1", "Ant 2", "Ant 3"].contains(name) {
            if let ps = src.psalmi {
                // DO-known source: the section exists only if DO has it.
                if let l = ps[name] {
                    guard let f = l.first else { return nil }
                    return Hour.Part(type: "antiphon", lat: f.ant, eng: f.antEng)
                }
                if !src.doKeyed { return nil }
            }
        }
        return src.sec(name)
    }

    /// DO getproprium: the proper's section, else the commune's when the
    /// commune is used "ex" (or [flag] forces it, as for capitula, hymns,
    /// versicles and canticle antiphons).
    private func proprium(_ o: Office, _ name: String, _ flag: Bool) -> Hour.Part? {
        // The Saturday office of the BVM: "(sed tempore paschali) Ant 1_Pasch".
        if (name == "Ant 1" || name == "Ant 2") && alleluiaRequired(o.dayName) &&
            (o.isC10 || (o.communeKey?.hasPrefix("C10") ?? false) || o.communeKey == "C12") {
            if let p = o.proper.sec("Ant 1_Pasch") ?? o.commune?.sec("Ant 1_Pasch") { return p }
        }
        if let p = name.hasPrefix("Ant ") ? antSec(o.proper, name) : o.proper.sec(name) { return p }
        if !(o.communeType == "ex" || flag) { return nil }
        guard let c = o.commune else { return nil }
        if let p = name.hasPrefix("Ant ") ? antSec(c, name) : c.sec(name) { return p }
        let sub: String?
        switch name {
        case "Nocturn 1 Versum": sub = "Versum 1"
        case "Versum Tertia": sub = "Nocturn 2 Versum"
        case "Versum Sexta": sub = "Nocturn 3 Versum"
        case "Versum Nona": sub = "Versum 2"
        default: sub = nil
        }
        if let sub, o.communeKey?.hasPrefix("C") ?? false, let p = c.sec(sub) { return p }
        // A pseudo-commune (ex Sancti/..) chains to its own commune.
        if let ck = o.communeKey, !ck.hasPrefix("C") {
            let r = riteRules(o.rite)[ck.after(":")]
            if let cc = r?.commune, let chained = srcFor(cc, o.rite) {
                if let p = chained.sec(name) { return p }
                if let sub, let p = chained.sec(sub) { return p }
            }
        }
        return nil
    }

    private func srcFor(_ ref: String, _ rite: MissalRite, date: LDate? = nil, paschal: Bool = false) -> Src? {
        if ref.hasPrefix("sancti:") {
            let k = ref.after(":")
            // A pseudo-commune read on another day resolves its conditionals
            // then; a file with "(tempore paschali)" sections has a Paschaltide form.
            let props = propersFor(rite)
            let dated = date.flatMap { props["\(ref)@\($0.mmdd)"] }
            let byDow = date.flatMap { props["\(ref)@dow\($0.dow)"] }
            let pasch = paschal ? props["\(ref)@pasch"] : nil
            if let p = dated ?? byDow ?? pasch ?? props[ref] { return Src(parts: p.parts, doKeyed: true, psalmi: p.psalmi) }
            if let p = sanctoralPropers[k] { return Src(parts: p, doKeyed: false, psalmi: ants["sancti:\(k)"]) }
            return nil
        }
        if ref.hasPrefix("tempora:") {
            let k = ref.after(":")
            if let p = propersFor(rite)[ref] { return Src(parts: p.parts, doKeyed: true, psalmi: p.psalmi) }
            if let p = temporalPropers[k] { return Src(parts: p, doKeyed: false, psalmi: ants["tempora:\(k)"]) }
            return nil
        }
        let base = communes[ref] ?? communes[ref.before("-")] ?? communes[String(ref.prefix { $0 == "C" || $0.isNumber })]
        return base.map { Src(parts: $0.parts, doKeyed: true, psalmi: $0.psalmi) }
    }

    private func psalmiLines(_ name: String) -> [AntLine]? { psalmiRaw(name).map { expand($0) } }

    private func psalmiRaw(_ name: String) -> [PsalmiLine]? {
        if let k = riteKey(), let v = psalterium.psalmi["\(name)|\(k)"] { return v }
        return psalterium.psalmi[name]
    }

    /// The rite being resolved: the psalter keeps a few sections per rite ("key|1955").
    private var riteCtx: MissalRite? = nil
    private func riteKey() -> String? { riteCtx?.rawValue }

    private func psalt(_ name: String) -> Hour.Part? {
        if let k = riteKey(), let v = psalterium.parts["\(name)|\(k)"] { return v }
        return psalterium.parts[name]
    }

    private func rekey(_ p: Hour.Part, _ vk: String, _ label: String? = nil) -> Hour.Part {
        var n = p
        n.variationKey = vk
        n.label = label ?? p.label
        return n
    }

    private func vrFrom(_ p: Hour.Part, _ vk: String) -> Hour.Part {
        if p.latR != nil {
            var n = p.withType("vr")
            n.variationKey = vk
            return n
        }
        let ls = lines(p)
        let es = engLines(p)
        let v = ls.first { $0.hasPrefix("℣") || $0.hasPrefix("V.") } ?? ls.first
        let r = ls.first { $0.hasPrefix("℟") || $0.hasPrefix("R.") }
        let ve = es.first { $0.hasPrefix("℣") || $0.hasPrefix("V.") } ?? es.first
        let re = es.first { $0.hasPrefix("℟") || $0.hasPrefix("R.") }
        var n = p.withType("vr")
        n.variationKey = vk
        n.lat = v; n.latR = r; n.eng = ve; n.engR = re
        return n
    }

    private func vrParts(_ v: AntLine?, _ r: AntLine?, _ vk: String) -> Hour.Part {
        var p = Hour.Part(type: "vr")
        p.label = "Versicle"
        p.lat = "℣. " + (v?.ant ?? "")
        p.latR = "℟. " + (r?.ant ?? "")
        p.eng = v?.antEng.map { "℣. " + $0 }
        p.engR = r?.antEng.map { "℟. " + $0 }
        p.variationKey = vk
        return p
    }

    private func vrLines(_ p: Hour.Part?) -> (AntLine, AntLine)? {
        guard let p else { return nil }
        let n = vrFrom(p, "x")
        return (AntLine(ant: n.lat?.dropPrefix("℣. ").dropPrefix("V. "), antEng: n.eng?.dropPrefix("℣. ").dropPrefix("V. "), psalms: nil),
                AntLine(ant: n.latR?.dropPrefix("℟. ").dropPrefix("R. "), antEng: n.engR?.dropPrefix("℟. ").dropPrefix("R. "), psalms: nil))
    }

    private func antPart(_ lat: String?, _ eng: String?, _ vk: String, _ label: String) -> Hour.Part {
        var p = Hour.Part(type: "antiphon")
        p.label = label; p.lat = lat; p.eng = eng; p.variationKey = vk
        return p
    }

    private let alleluiaAnt = "Allelúja, * allelúja, allelúja."
    private let alleluiaAntEng = "Alleluia, * alleluia, alleluia."

    private func alleluiaRequired(_ dn: String) -> Bool { dn.hasPrefix("Pasc") }

    private let alleluiaRe = "allel[uú]j?[ia]"

    /// DO ensure_single_alleluia: append ", allelúja." unless present.
    private func single(_ text: String?, _ eng: Bool) -> String? {
        guard let t = text else { return nil }
        if t.isBlank { return t }
        if t.takeLast(14).has(alleluiaRe, ci: true) { return t }
        let a = eng ? "alleluia" : "allelúja"
        return t.trimmed.trimEnd(".,;:") + ", \(a)."
    }

    /// DO ensure_double_alleluia: "A * B." -> "A b, * Allelúja, allelúja."
    private func double(_ text: String?, _ eng: Bool) -> String? {
        guard let t = text else { return nil }
        let a = eng ? "Alleluia" : "Allelúja"
        if t.has("\(alleluiaRe)[,.] \(alleluiaRe)\\p{P}?\\s*$", ci: true) { return t }
        let noStar = t.rreplace("\\s*\\*\\s*(\\S)") { g in " " + g[1].lowercased() }
        return noStar.trimmed.trimEnd(".,;:") + ", * \(a), \(a.lowercased())."
    }

    private func alleluiaVersicle(_ p: Hour.Part) -> Hour.Part {
        var n = p
        n.lat = single(p.lat, false); n.latR = single(p.latR, false)
        n.eng = single(p.eng, true); n.engR = single(p.engR, true)
        return n
    }

    private func alleluiaResponsory(_ p: Hour.Part) -> Hour.Part {
        func conv(_ text: String?, _ eng: Bool) -> String? {
            guard let ls = text?.lines else { return nil }
            var out: [String] = []
            var afterV = false
            for l in ls {
                if l.hasPrefix("℟.br.") {
                    out.append("℟.br. " + (double(l.dropPrefix("℟.br.").trimmed, eng) ?? "")); afterV = false
                } else if l.hasPrefix("℣.") {
                    out.append("℣. " + (single(l.dropPrefix("℣.").trimmed, eng) ?? "")); afterV = true
                } else if l.hasPrefix("℟.") && afterV {
                    out.append("℟. " + (eng ? "Alleluia, alleluia." : "Allelúja, allelúja.")); afterV = false
                } else if l.hasPrefix("℟.") {
                    out.append("℟. " + (double(l.dropPrefix("℟.").trimmed, eng) ?? ""))
                } else {
                    out.append(l)
                }
            }
            return out.joined(separator: "\n")
        }
        var n = p
        n.lat = conv(p.lat, false); n.eng = conv(p.eng, true)
        return n
    }

    private func emberDay(_ o: Office, _ dow: Int) -> Bool {
        [3, 5, 6].contains(dow) && (["Adv3", "Quad1", "Pasc7"].contains(o.dayName) ||
            o.name.containsCI("Quattuor Temporum") || o.name.containsCI("Quatuor Temporum"))
    }

    private func is1960(_ rite: MissalRite) -> Bool { rite == .rite1962 }
    private func is1955or1960(_ rite: MissalRite) -> Bool { rite == .rite1962 || rite == .rite1955 }

    private func psalmPart(_ vk: String, _ refs: [String], _ ant: String?, _ antEng: String?) -> Hour.Part {
        let first = refs[0]
        let num = Int(first.before(":")) ?? 0
        let isCant = num >= 210
        let ref: String
        if refs.count > 1 { ref = "Ps " + refs.joined(separator: ",") }
        else if isCant { ref = "Cant \(first)" }
        else { ref = "Ps \(first)" }
        let label: String
        if isCant { label = "Canticum" }
        else if refs.count > 1 { label = "Psalmi " + refs.joined(separator: ", ") }
        else if first.contains(":") { label = "Psalmus \(first.before(":")) (\(first.after(":")))" }
        else { label = "Psalmus \(first)" }
        let a = ant.flatMap { $0.isBlank ? nil : $0 }
        var p = Hour.Part(type: isCant ? "canticle" : "psalm")
        p.label = label; p.ref = ref; p.variationKey = vk
        p.antiphonLat = a
        p.antiphonEng = a != nil ? antEng : nil
        return p
    }

    /// DO gettempora.
    private func tempora(_ caller: String, _ o: Office, _ dow: Int, _ rite: MissalRite) -> String {
        let dn = o.dayName
        let day = o.date.day
        var t: String
        if dn.matchesWhole("Adv[34]") && caller == "Invitatorium" { t = "Adv3" }
        else if dn.hasPrefix("Adv") && caller != "Doxology" && caller != "Nunc dimittis" { t = "Adv" }
        else if dn.has("^Quad[56]") && caller != "Doxology" { t = "Quad5" }
        else if dn.hasPrefix("Quad") && !dn.hasPrefix("Quadp") && caller != "Doxology" { t = "Quad" }
        else if dn.hasPrefix("Pasc6") || (dn.hasPrefix("Pasc5") && dow > 3 && !o.isSunday) { t = "Asc" }
        else if dn.has("^Pasc[0-5]") { t = "Pasch" }
        else if dn.hasPrefix("Pasc7") { t = "Pent" }
        else { t = "" }
        if (caller == "Psalmi minor" || caller == "Invitatorium" || caller == "Hymnus matutinum") && (t == "Asc" || t == "Pent") { t = "Pasch" }
        if caller == "Lectio brevis Prima" && t.isEmpty { t = "Per Annum" }
        if caller == "Hymnus major" && t.isEmpty { t = "Day\(dow)" }
        if (caller.hasPrefix("Capitulum") || caller.hasSuffix("major")) && t.isEmpty {
            t = (dow == 0 || (caller == "Capitulum minor" && o.rankHas("Duplex") && !o.rankHas("Dominica|Vigilia"))) ? "Dominica" : "Feria"
        }
        if caller == "Doxology" || caller == "Prima responsory" || (is1960(rite) && caller != "Psalmi minor" && caller != "Nunc dimittis") {
            if dn.hasPrefix("Nat") {
                t = (6...12).contains(day) ? "Epi" : "Nat"
            } else if dn.has("^Epi[01]") && day < 14 {
                t = "Epi"
            }
        }
        return t
    }

    /// DO dayofweek2i.
    private func dow2i(_ dow: Int) -> Int {
        switch dow { case 1, 4, 0: return 1; case 2, 5: return 2; default: return 3 }
    }

    // MARK: offices

    static func dayNameOf(_ temporalKey: String?) -> String {
        guard let k = temporalKey, let m = k.rmatch("^([a-z]+)(\\d*)") else { return "" }
        let prefix = m[1]
        let num = m[2]
        switch prefix {
        case "adv": return "Adv\(num)"
        case "quadp": return "Quadp\(num)"
        case "quad": return "Quad\(num)"
        case "pasc": return "Pasc\(num)"
        case "pent": return "Pent\(num)"
        case "epi": return "Epi\(num)"
        case "nat": return (Int(num) ?? 0) < 7 ? "Nat1" : "Nat2"
        default: return ""
        }
    }

    /// Variation keys the rubrics own; the older proper/commune layering
    /// must not override them.
    static func ownedKey(_ key: String) -> Bool {
        key == "invit" || key.hasPrefix("hymnus_") || key.hasSuffix(".hymn") ||
            key.hasPrefix("ant_") || key.hasPrefix("matutinum.") ||
            key.hasPrefix("laudes.") || key.hasPrefix("vesperae.") ||
            key.hasPrefix("prima.psalm") || key == "prima.capitulum" || key == "prima.responsory" ||
            key == "versum_prima" || key == "lectio_prima" ||
            key.hasPrefix("tertia.") || key.hasPrefix("sexta.") || key.hasPrefix("nona.") ||
            key.hasPrefix("capitulum_") || key.hasPrefix("responsory_breve_") ||
            key.hasPrefix("versum_") || key.hasPrefix("nocturn_") ||
            key == "completorium.antiphon" || key.hasPrefix("completorium.psalm") ||
            key == "completorium.hymn" || key == "completorium.capitulum" || key == "completorium.responsory" ||
            key == "completorium.canticle"
    }

    func officeFor(_ ordo: OrdoEntry, _ date: LDate, _ rite: MissalRite) -> Office {
        let rr = riteRules(rite)
        let sanctoral = ordo.winner == "sanctoral"
        let key = ordo.winnerKey
        let dateKey = date.mmdd
        let rule: OfficeRule?
        if key.hasPrefix("bvm-sab") { rule = rr["C10"] }
        else if sanctoral { rule = rr[key] ?? rr[key.take(5)] }
        else if key.hasPrefix("nat") { rule = rr[dateKey] ?? rr[key] }
        else { rule = rr[key] ?? rr[key.dropSuffix("o")] }
        var proper: [String: Hour.Part] = [:]
        if sanctoral {
            if let p = sanctoralPropers[key] { proper.merge(p) { _, n in n } }
            if rite == .pre1955, let p = sanctoralPropers[key + "o"] { proper.merge(p) { _, n in n } }
        } else {
            if let p = temporalPropers[key] { proper.merge(p) { _, n in n } }
            if rite == .pre1955, let p = temporalPropers[key + "o"] { proper.merge(p) { _, n in n } }
        }
        var communeKey: String? = rule?.commune
        var communeType: String? = rule?.communeType
        if communeKey == nil && sanctoral {
            if let inh = saintOfficeInherit[key] { communeKey = "sancti:\(inh)"; communeType = "ex" }
            else if let c = saintCommune[key] ?? saintCommune[key.take(5)] { communeKey = c; communeType = communeType ?? "vide" }
        }
        if key.hasPrefix("bvm-sab") { communeKey = "C10"; communeType = "ex" }
        let commune = communeKey.flatMap { srcFor($0, rite) }
        // DO: the commune's Rule applies only when the office is "ex" its commune.
        let communeRuleAny: String = communeKey.map { ck -> String in
            let fk = ck.contains(":") ? ck.after(":") : ck
            return rr[fk]?.rule ?? commune?.rule ?? ""
        } ?? ""
        let communeRule = communeType == "ex" ? communeRuleAny : ""
        let antsKey = sanctoral ? (key.hasPrefix("bvm-sab") ? "C10" : "sancti:\(key)") : "tempora:\(key)"
        let props = propersFor(rite)
        let doProper: OfficePsalterium?
        if key.hasPrefix("bvm-sab") { doProper = communes["C10"] }
        else if sanctoral { doProper = props["sancti:\(key)"] ?? props["sancti:" + key.take(5)] }
        else if key.hasPrefix("nat") { doProper = props["sancti:\(dateKey)"] }
        else { doProper = props["tempora:\(key)"] ?? props["tempora:" + key.dropSuffix("o")] }
        let properSrc = doProper.map { Src(parts: $0.parts, doKeyed: true, psalmi: $0.psalmi) }
            ?? Src(parts: proper, doKeyed: false, psalmi: ants[antsKey])
        let dow = date.dow
        let rankLine = rule?.rankLine
            ?? (ordo.name + ";;" + (sanctoral ? "Duplex" : (dow == 0 ? "Dominica" : "Feria")) + ";;" + String(ordo.rank))
        return Office(
            sanctoral: sanctoral, key: key,
            rank: rule?.rank ?? ordo.rank, rankLine: rankLine, rule: rule?.rule ?? "",
            communeType: commune != nil ? communeType : nil,
            communeKey: commune != nil ? communeKey : nil,
            communeRule: communeRule, communeRuleAny: communeRuleAny,
            proper: properSrc, commune: commune,
            temporalKey: ordo.temporal, dayName: OfficeRubrics.dayNameOf(ordo.temporal), name: ordo.name, date: date, rite: rite)
    }

    /// The app's proper for a DO office key (sancti:01-21 / tempora:pent02-0r).
    private func appProper(_ key: String) -> [String: Hour.Part]? {
        let k = key.after(":")
        if key.hasPrefix("sancti:") { return sanctoralPropers[k] ?? sanctoralPropers[k.take(5)] }
        return temporalPropers[k] ?? temporalPropers[k.dropSuffix("feria").dropSuffix("r")]
    }

    /// An office from DO's own precedence.
    func officeFrom(_ d: DoOffice, _ date: LDate, _ rite: MissalRite) -> Office {
        let rr = riteRules(rite)
        let sanctoral = !d.w.hasPrefix("tempora:")
        let key = d.w.after(":")
        let rule = rr[key] ?? rr[key.take(5)]
        let dn = d.d ?? ""
        let props = propersFor(rite)
        var doProper: OfficePsalterium? = props["\(d.w)@dow\(date.dow)"]
            ?? (alleluiaRequired(dn) ? props["\(d.w)@pasch"] : nil) ?? props[d.w]
            ?? (!d.w.contains(":") ? (communes[d.w] ?? communes[d.w.dropSuffix("Pasc")]) : nil)
        // The scripture-cycle file of the week (Aug-Nov) overlays the Sunday's
        // own sections (DO officestring: every key but the Rank).
        let mdKey: String? = d.md.flatMap { m in
            (d.w.has("^tempora:(pent|epi)") && !d.w.has("^tempora:pent0[1-5]")) ? m : nil
        }
        let md = mdKey.flatMap { props[$0] }
        if let md {
            var parts = doProper?.parts ?? [:]
            parts.merge(md.parts) { _, n in n }
            var psalmi = doProper?.psalmi ?? [:]
            psalmi.merge(md.psalmi) { _, n in n }
            doProper = OfficePsalterium(parts: parts, psalmi: psalmi)
        }
        let proper = doProper.map { Src(parts: $0.parts, doKeyed: true, psalmi: $0.psalmi) }
            ?? Src(parts: appProper(d.w) ?? [:], doKeyed: false, psalmi: ants[d.w])
        let commune = d.c.flatMap { srcFor($0, rite, date: date, paschal: alleluiaRequired(dn)) }
        let communeRuleAny: String = d.c.map { ck -> String in
            let fk = ck.contains(":") ? ck.after(":") : ck
            return rr[fk]?.rule ?? commune?.rule ?? ""
        } ?? ""
        let communeRule = d.t == "ex" ? communeRuleAny : ""
        let n = d.n ?? ""
        let rankLine = n.isBlank ? (rule?.rankLine ?? "") : n
        return Office(
            sanctoral: sanctoral, key: key,
            rank: d.r ?? 0, rankLine: rankLine, rule: md?.parts["Rule"]?.lat ?? rule?.rule ?? proper.rule,
            communeType: commune != nil ? d.t : nil,
            communeKey: commune != nil ? d.c : nil,
            communeRule: communeRule, communeRuleAny: communeRuleAny,
            proper: proper, commune: commune,
            temporalKey: nil, dayName: dn, name: n.before(";;").before(" Duplex").before(" Semiduplex").before(" Feria"),
            date: date, rite: rite, laudesDO: d.ls ?? 1, duplexDO: d.dx ?? 3, commemorations: d.cm ?? [], commemorations1: d.cm1 ?? [],
            mdKey: mdKey, anteCapitulum: d.ac, anteCapitulum5: d.ac5, hymnShift: d.hy ?? 0, transferVigil: d.tv,
            octVespera: d.ov ?? 0, emberSept: d.qt ?? false, commemoratioKey: d.co)
    }

    /// The collect of the day for an hour (DO oratio()).
    private func oratioOf(_ o: Office, _ hourSlug: String, _ vespera: Int, _ dowIn: Int? = nil) -> Hour.Part? {
        let dow = dowIn ?? o.date.dow
        let ind = hourSlug == "vesperae" ? vespera : 2
        var rule = o.rule
        if o.dayName.hasPrefix("Epi1") && rule.containsCI("Infra octavam Epiphaniæ Domini") && is1955or1960(o.rite) {
            rule += "\nOratio Dominica"
        }
        let win = o.proper
        var w: Src = win
        if rule.has("Oratio Dominica", ci: true) ||
            (o.rankHas("Quattuor") && !o.dayName.hasPrefix("Pasc7") && !is1960(o.rite) && hourSlug == "vesperae") {
            var name = "\(o.dayName)-0"
            if name.has("Epi1|Nat", ci: true) { name = "Epi1-0a" }
            if let s = srcFor("tempora:" + name.lowercased(), o.rite) { w = s }
        }
        // "(nisi ad vesperam aut rubrica 196)": the September Ember days'
        // own collect is not said at Vespers in the older books.
        let emberVespers = hourSlug == "vesperae" && !is1960(o.rite) && (o.mdKey?.matchesWhole("tempora:09\\d-[356]") ?? false)
        var p: Hour.Part?
        if emberVespers { p = nil }
        else if dow > 0 && win.sec("OratioW") != nil && o.rank < 5 { p = w.sec("OratioW") }
        else { p = w.sec("Oratio") }
        if hourSlug == "matutinum" && win.sec("Oratio Matutinum") != nil { p = w.sec("Oratio Matutinum") }
        else if p == nil || win.sec("Oratio \(ind)") != nil { p = w.sec("Oratio \(ind)") }
        let c = o.commune
        if p == nil, let c { p = c.sec("Oratio \(ind)") ?? c.sec("Oratio \(4 - ind)") ?? c.sec("Oratio") }
        if p == nil {
            var i = ind
            if i == 2 { i = 3; p = w.sec("Oratio 3") } else { p = w.sec("Oratio 2") }
            if p == nil { i = 4 - i; p = w.sec("Oratio \(i)") }
        }
        if p == nil, let c { p = c.sec("Oratio") ?? c.sec("Oratio \(ind)") }
        if p == nil && o.temporal {
            if let sd = srcFor("tempora:\(o.dayName.lowercased())-0", o.rite) { p = sd.sec("Oratio") ?? sd.sec("Oratio 2") }
        }
        return p.map { withName($0, w.sec("Name") != nil ? w : win) }
    }

    // MARK: names, inline alleluias

    /// DO replaceNdot: the name the proper's [Name] gives for "N." in a text.
    private func nameFor(_ src: Src?, _ text: String, _ eng: Bool) -> String? {
        guard let np = src?.sec("Name") else { return nil }
        guard let raw = eng ? (np.eng ?? np.lat) : np.lat else { return nil }
        var ls = raw.lines.map { $0.trimmed }.filter { !$0.isEmpty }
        if ls.isEmpty { return nil }
        if text.has("^[OÓ],?\\s|O Doctor optime") && ls.contains(where: { $0.hasPrefix("Ant=") }) { ls = ls.filter { $0.hasPrefix("Ant=") } }
        else if text.has("^L..*N\\.\\.") && ls.contains(where: { $0.hasPrefix("Invit=") }) { ls = ls.filter { $0.hasPrefix("Invit=") } }
        else if ls.contains(where: { $0.hasPrefix("Oratio=") }) { ls = ls.filter { $0.hasPrefix("Oratio=") } }
        let v = ls[0].after("=").trimmed
        return v.isEmpty ? nil : v
    }

    private func replaceNdot(_ text: String?, _ name: String?) -> String? {
        guard let text, let name, text.contains("N.") else { return text }
        let re = RegexCache.shared.get("N\\. .*? N\\.", ci: false)
        var t = text
        if let m = re.firstMatch(in: t, range: t.full) {
            t = t.ns.replacingCharacters(in: m.range, with: name)
        }
        return t.replacingOccurrences(of: "N.", with: name)
    }

    /// Spanish for a templated Latin text (the "N." still in it), and the
    /// Spanish form of a proper's [Name] value; nil in English. Set by the
    /// ContentStore when the vernacular is Spanish.
    var spanishText: ((String) -> String?)? = nil
    var spanishName: ((String) -> String?)? = nil

    /// The office's [Name] filled into every "N." of a part. In Spanish the
    /// vernacular is taken from the template before the name goes in, with
    /// the name in its Spanish form; the English is never touched.
    private func withName(_ p: Hour.Part, _ src: Src?) -> Hour.Part {
        if src?.sec("Name") == nil { return p }
        func f(_ t: String?, _ eng: Bool) -> String? {
            guard let t, t.contains("N.") else { return t }
            return replaceNdot(t, nameFor(src, t, eng))
        }
        func es(_ latT: String?) -> String? {
            guard let lookup = spanishText, let latT, latT.contains("N.") else { return nil }
            guard let template = lookup(latT), let nameLat = nameFor(src, latT, false) else { return nil }
            guard let nameEs = spanishName?(nameLat) ?? nameFor(src, latT, true) else { return nil }
            return replaceNdot(template, nameEs)
        }
        var n = p
        n.lat = f(p.lat, false); n.latR = f(p.latR, false)
        n.eng = es(p.lat) ?? f(p.eng, true); n.engR = es(p.latR) ?? f(p.engR, true)
        n.antiphonLat = f(p.antiphonLat, false); n.antiphonEng = es(p.antiphonLat) ?? f(p.antiphonEng, true)
        return n
    }

    private let parenAlleluia = "\\s*\\((allel[uú]j?[ia][^)]*)\\)"
    private let anyAlleluia = "[,.]?\\s*allel[uú][ij]a"

    /// Whether the hour falls in the alleluia-less season (Septuagesima to
    /// Holy Saturday), the Saturday Vespers before Septuagesima excepted.
    func lentSuppressed(_ o: Office, _ hourSlug: String, _ dow: Int, _ vespera: Int) -> Bool {
        if !o.dayName.has("Quadp|Quad[1-5]|Quad6-[0-5]") { return false }
        let septVesp = dow == 6 && (hourSlug == "vesperae" || hourSlug == "completorium") && vespera == 1 && o.dayName.hasPrefix("Quadp1")
        return !septVesp
    }

    private func withoutAlleluia(_ p: Hour.Part) -> Hour.Part {
        func f(_ t: String?) -> String? { t.map { $0.has(anyAlleluia, ci: true) ? $0.rreplace(anyAlleluia, "", ci: true) : $0 } }
        if ![p.lat, p.latR, p.eng, p.engR, p.antiphonLat, p.antiphonEng].contains(where: { $0 != nil && $0!.has(anyAlleluia, ci: true) }) { return p }
        var n = p
        n.lat = f(p.lat); n.latR = f(p.latR); n.eng = f(p.eng); n.engR = f(p.engR)
        n.antiphonLat = f(p.antiphonLat); n.antiphonEng = f(p.antiphonEng)
        return n
    }

    /// DO process_inline_alleluias: a bracketed "(Allelúja.)" is said in
    /// Paschaltide and dropped outside it.
    private func inlineAlleluia(_ t: String?, _ paschal: Bool) -> String? {
        guard let t, t.contains("(") else { return t }
        if paschal {
            return t.rreplace(parenAlleluia, ci: true) { g in " " + g[1] }.rreplace(" {2,}", " ")
        }
        return t.rreplace(parenAlleluia, "", ci: true).trimEnd(" ")
    }

    private func withInlineAlleluia(_ p: Hour.Part, _ paschal: Bool) -> Hour.Part {
        func has(_ t: String?) -> Bool { t?.contains("(") ?? false }
        if !has(p.lat) && !has(p.latR) && !has(p.eng) && !has(p.engR) && !has(p.antiphonLat) && !has(p.antiphonEng) { return p }
        var n = p
        n.lat = inlineAlleluia(p.lat, paschal); n.latR = inlineAlleluia(p.latR, paschal)
        n.eng = inlineAlleluia(p.eng, paschal); n.engR = inlineAlleluia(p.engR, paschal)
        n.antiphonLat = inlineAlleluia(p.antiphonLat, paschal); n.antiphonEng = inlineAlleluia(p.antiphonEng, paschal)
        return n
    }

    // MARK: commemorations (DO getcommemoratio, vigilia_commemoratio, commemoratio)

    /// The pieces of a commemoration (DO getcommemoratio): its canticle
    /// antiphon, versicle and collect, keyed for insertCommemoration
    /// (ant_N / versum_N / oratio, N = 2 at Lauds, the Vespers kind
    /// [vesperaOf] otherwise). Empty when the rubrics make none.
    func commemorationData(_ key: String, _ hourSlug: String, _ date: LDate, _ rite: MissalRite, vesperaOf: Int = 3,
                           winner: Office? = nil, vespera: Int = 3) -> [String: Hour.Part] {
        let ind = hourSlug == "laudes" ? 2 : vesperaOf
        let w = officeFromKey(key, date, rite, tomorrow: ind == 1, dayName: winner?.dayName ?? "")
        let wr = winner?.rank ?? 0
        let dn = winner?.dayName ?? w.dayName
        if let winner, winner.ruleHas("no\\s+(\\w+)?\\s*commemoratio") {
            let which = winner.rule.rmatch("no\\s+(\\w+)?\\s*commemoratio", ci: true)?[1] ?? ""
            if (which.isEmpty || key.containsCI(which)) && !(hourSlug == "vesperae" && vespera == 3 && ind == 1) { return [:] }
        }
        if is1960(rite) && hourSlug == "vesperae" && ind == 3 && wr >= 6 &&
            !w.rankHas("Adv|Quad|Passio|Epi|Corp|Nat|Cord|Asc|Dominica|;;6") { return [:] }
        let rp = w.rankLine.components(separatedBy: ";;").map { $0.trimmed }
        let r2 = (rp.count > 2 ? Double(rp[2]) : nil) ?? w.rank
        if r2 < 2.1 && r2 != 1.15 && ((rp.count > 1 ? rp[1] : "").contains("Feria") ||
            ((rp.count > 0 ? rp[0] : "").containsCI("Infra Octav") && wr >= 5 && (winner?.sanctoral ?? false))) { return [:] }
        // The commune the commemoration draws on ("ex" or "vide" alike).
        var c: Src? = nil
        if let m = (rp.count > 3 ? rp[3] : "").rmatch("(ex|vide)\\s+(.*?)\\s*$", ci: true) {
            var file = m[2].trimmed
            if let cx = w.rule.rmatch("Comex=(.*?);", ci: true), wr < 5 { file = cx[1].trimmed }
            file = paschalCommune(file, dn)
            var src = srcFor(communeRef(file), rite)
            // A daisy-chained commune reference, one level down.
            let chain = riteRules(rite)[file]?.rankLine?.rmatch(";;(ex|vide)\\s+(.*?)\\s*$", ci: true)
            if let s = src, let chain {
                let f2 = paschalCommune(chain[2].trimmed, dn)
                if let s2 = srcFor(communeRef(f2), rite) {
                    let keep: Set<String> = ["Oratio", "Ant 1", "Ant 2", "Ant 3", "Versum 1", "Versum 2", "Versum 3"]
                    var parts = s2.parts.filter { keep.contains($0.key) }
                    parts.merge(s.parts) { _, n in n }
                    src = Src(parts: parts, doKeyed: true, psalmi: s.psalmi)
                }
            }
            c = src
        }
        // The collect.
        var o: Hour.Part? = w.proper.sec("Oratio").map { withName($0, w.proper) }
        if o == nil && w.ruleHas("Oratio Dominica") {
            var wday = w.key.rreplace("-[0-9]", "-0")
            if wday.contains("epi1-0") { wday = wday.replacingOccurrences(of: "epi1-0", with: "epi1-0a") }
            if let sd = srcFor("tempora:\(wday)", rite) { o = sd.sec("OratioW") ?? sd.sec("Oratio") }
        }
        if o == nil { o = w.proper.sec("Oratio \(ind)") ?? w.proper.sec("Oratio \(4 - ind)") ?? c?.sec("Oratio") }
        o = o.map { withName($0, w.proper) }
        guard let oratio = o, !oratio.lat.isNullOrBlank else { return [:] }
        // The antiphon.
        var a: Hour.Part? = antSec(w.proper, "Ant \(ind)")
        let epi1Special = winner != nil && (winner!.key == "epi1-0a" || winner!.key == "01-12t") && hourSlug == "vesperae" && vespera == 3
        if a == nil || epi1Special {
            a = !w.key.has("epi[2-6]-0") ? antSec(w.proper, "Ant \(4 - ind)") : psalt("Feria Ant 3")
        }
        if a == nil { a = c.flatMap { antSec($0, "Ant \(ind)") } }
        a = a.map { withName($0, w.proper) }
        if w.temporal && date.month == 12 &&
            ((hourSlug == "vesperae" && (17...23).contains(date.day)) || (hourSlug == "laudes" && (date.day == 21 || date.day == 23))) {
            a = psalt(hourSlug == "vesperae" ? "Adv Ant \(date.day)" : "Adv Ant \(date.day)L") ?? a
        }
        guard let ant = a, !lines(ant).isEmpty else {
            // DO: a vigil without antiphon of its own takes the ferial form at Lauds.
            return (hourSlug == "laudes" && w.rankHas("Vigilia")) ? vigilCommemoration(w, winner, date, rite, false) : [:]
        }
        // The versicle.
        var v: Hour.Part? = w.proper.sec("Versum \(ind)")
        if let winner, winner.key == "epi1-0a" || winner.key == "01-12t" {
            v = (vespera == 1 && date.day == 10) ? c?.sec("Versum 2") : c?.sec("Versum Tertia")
        }
        if v == nil { v = w.proper.sec("Versum \(4 - ind)") ?? c?.sec("Versum \(ind)") ?? c?.sec("Versum \(4 - ind)") }
        if v == nil {
            // DO getfrompsalterium('Versum', ind): the season's psalter versicle.
            let name = tempora("getfrompsalterium major", winner ?? w, date.dow, rite) + " Versum"
            v = psalt("\(name) \(ind)") ?? psalt("\(name) 1") ?? psalt("\(name) 3") ?? psalt("\(name) 2")
        }
        let paschal = alleluiaRequired(dn)
        var out: [String: Hour.Part] = [:]
        out["name"] = { var p = Hour.Part(type: "rubric"); p.lat = rp.first ?? w.name; return p }()
        var ap = ant.withType("antiphon")
        ap.lat = lines(ant)[0]; ap.eng = engLines(ant).first; ap.variationKey = nil
        out["ant_\(ind)"] = withInlineAlleluia(ap, paschal)
        if let v {
            var vr = withInlineAlleluia(vrFrom(v, "versum_\(ind)"), paschal)
            if paschal && !w.ruleHas("C9|C12") { vr = alleluiaVersicle(vr) }
            out["versum_\(ind)"] = vr
        }
        var op = oratio.withType("collect")
        op.label = "Oratio"; op.variationKey = "oratio"
        out["oratio"] = withInlineAlleluia(op, paschal)
        return out
    }

    /// DO vigilia_commemoratio: a vigil commemorated at Lauds with the
    /// ferial Benedictus antiphon and versicle and its own collect
    /// ([useVigilia]: the "Oratio Vigilia" a feast carries for its vigil).
    private func vigilCommemoration(_ w: Office, _ winner: Office?, _ date: LDate, _ rite: MissalRite, _ useVigilia: Bool) -> [String: Hour.Part] {
        let dn = winner?.dayName ?? w.dayName
        let dow = date.dow
        if is1955or1960(rite) {
            if !w.key.has("^(08-14|06-23|06-28|08-09)") { return [:] }
        } else if dn.has("Adv|Quad[0-6]") || (dn.hasPrefix("Quadp3") && dow >= 4) || (winner?.emberSept ?? false) { return [:] }
        var o: Hour.Part? = useVigilia ? w.proper.sec("Oratio Vigilia") : w.proper.sec("Oratio")
        if o == nil && !useVigilia && w.rankHas("(ex|vide) C1v") { o = srcFor("C1v", rite)?.sec("Oratio").map { withName($0, w.proper) } }
        if o == nil && useVigilia { o = w.proper.sec("Oratio Vigilia") }
        guard let oratio = o, !oratio.lat.isNullOrBlank else { return [:] }
        // The ferial Benedictus antiphon of the weekday (none on a Sunday).
        let a = dow == 0 ? nil : (psalt("Feria\(dow + 1) Ant 2") ?? psalt("Feria Ant 2"))
        let v = psalt("Feria Versum 2")
        var out: [String: Hour.Part] = [:]
        out["name"] = { var p = Hour.Part(type: "rubric"); p.lat = w.rankHas("Vigilia") ? w.rankLine.before(";;") : "Vigilia"; return p }()
        if let a {
            var ap = a.withType("antiphon")
            ap.lat = (a.lat ?? "").rreplace("\\s*\\*\\s*", " ")
            ap.variationKey = nil
            out["ant_2"] = ap
        }
        if let v { out["versum_2"] = vrFrom(v, "versum_2") }
        var op = withName(oratio, w.proper).withType("collect")
        op.label = "Oratio"; op.variationKey = "oratio"
        out["oratio"] = op
        return out
    }

    /// DO: the martyrs' communes (C1-C3) take their Paschaltide form.
    private func paschalCommune(_ file: String, _ dayName: String) -> String {
        (file.has("^C[1-3](?![v\\d])") && dayName.hasPrefix("Pasc")) ? file.dropSuffix("p") + "p" : file
    }

    private func communeRef(_ file: String) -> String {
        if file.hasPrefix("Sancti/") { return "sancti:" + file.dropPrefix("Sancti/").dropSuffix(".txt") }
        if file.hasPrefix("Tempora/") { return "tempora:" + file.dropPrefix("Tempora/").dropSuffix(".txt").lowercased() }
        return file.dropPrefix("Commune/").dropSuffix(".txt")
    }

    /// The commemorations of an hour in DO's order: the concurrent office
    /// first at Vespers, then the Sundays, then by rank; each as the map
    /// insertCommemoration takes.
    func commemorationsFor(_ hourSlug: String, _ date: LDate, _ rite: MissalRite, _ res: Resolution) -> [[String: Hour.Part]] {
        riteCtx = rite
        let o = res.office
        // DO: no commemorations at all on a Duplex I classis of the first rank (rank 7).
        if o.rank >= 7 { return [] }
        var entries: [(Double, [String: Hour.Part])] = []
        var ccind = 0
        let vespers = hourSlug == "vesperae"
        let sunday = "Dominic[aæ]"
        let octaveRe = "O[ckt]t[aá]|Octava"
        // DO $octvespera: the Vespers (1 or 3) an octave's commemoration is
        // taken from at the Saturday/Sunday boundary (the older books).
        let ov = (vespers && !is1960(rite)) ? o.octVespera : 0
        func nameOf(_ d: [String: Hour.Part]) -> String { d["name"]?.lat ?? "" }
        // The office's own [Commemoratio] sections.
        for d in ownCommemorations(o, hourSlug, res.vespera, date, rite, ov) {
            ccind += 1
            let t = nameOf(d)
            let key: Double
            if t.has(sunday, ci: true) { key = 3000 }
            else if t.has(octaveRe, ci: true) { key = (res.commemoration == nil && ov != 0) ? 1000 : Double(ccind + 7900) }
            else { key = Double(ccind + 9900) }
            entries.append((key, d))
        }
        if vespers, let cw = res.commemoration {
            var d = commemorationData(cw.keyRef, hourSlug, date, rite, vesperaOf: res.commemorationVespera, winner: o, vespera: res.vespera)
            // "Substitute Commemoratio of Octave to Vesp-$octvespera".
            if !d.isEmpty && ov != 0 && ov != res.commemorationVespera && nameOf(d).has(octaveRe, ci: true) {
                d = commemorationData(cw.keyRef, hourSlug, date, rite, vesperaOf: ov, winner: o, vespera: res.vespera)
            }
            if !d.isEmpty {
                ccind += 1
                let key: Double = cw.ruleHas("infra Octavam Epi") ? 5600 : 9000
                entries.append((10000 - key, d))
                for (i, e) in embeddedCommemorations(cw, res.commemorationVespera, o, hourSlug).enumerated() {
                    entries.append((10000 - key + 0.1 * Double(i + 1), e))
                }
            }
        }
        // A commemoration the collect carries itself ("@File:CommemoratioN"
        // after the collect): printed with it at Lauds and Vespers.
        let ind = vespers ? res.vespera : 2
        for name in ["Oratio \(ind) Commemoratio", "Oratio Commemoratio"] {
            guard let sec = o.proper.sec(name) else { continue }
            for block in (sec.lat ?? "").rsplit("\\n(?=!)").filter({ !$0.isBlank }) {
                if hourSlug == "laudes" && block.has("precedenti|sequenti", ci: true) { continue }
                guard let d = parseCommemorationBlock(block, nil, ind, o) else { continue }
                entries.append((0, d))
            }
            break
        }
        if vespers, let cw = res.commemoration {
            for d in fileCommemorations(cw, o, hourSlug, res.commemorationVespera, date, rite, ov) {
                ccind += 1
                entries.append((nameOf(d).has(sunday, ci: true) ? 3000 : Double(ccind + 9900), d))
            }
        }
        // A vigil falling on a Sunday, commemorated the day before (DO $transfervigil).
        if !vespers, let tv = o.transferVigil {
            let dv = vigilCommemoration(officeFromKey(tv, date, rite, dayName: o.dayName), o, date, rite, false)
            if !dv.isEmpty { ccind += 1; entries.append((Double(ccind + 8500), dv)) }
        }
        let lists: [(Int, [String])] = vespers ? [(1, o.commemorations1), (3, o.commemorations)] : [(2, o.commemorations)]
        for (cv, list) in lists {
            for ck in list {
                let w = officeFromKey(ck, date, rite, tomorrow: cv == 1, dayName: o.dayName)
                // An octave's day commemorated at the Saturday/Sunday boundary takes DO's $octvespera.
                let cvUse = (ov != 0 && w.rankHas("in.*octavam|post Octavam Asc")) ? ov : cv
                let d = commemorationData(ck, hourSlug, date, rite, vesperaOf: cvUse, winner: o, vespera: res.vespera)
                if d.isEmpty { continue }
                let rp = w.rankLine.components(separatedBy: ";;").map { $0.trimmed }
                let r2 = (rp.count > 2 ? Double(rp[2]) : nil) ?? w.rank
                let key: Double = ((rp.first ?? "").has(sunday, ci: true) || ck.hasSuffix("01-05")) ? 7000 : r2 * 1000
                ccind += 1
                entries.append((10000 - key + Double(ccind), d))
                for (i, e) in embeddedCommemorations(w, cv, o, hourSlug).enumerated() {
                    entries.append((10000 - key + Double(ccind) + 0.1 * Double(i + 1), e))
                }
                if cv == 2 && date.dow != 0 && w.proper.sec("Oratio Vigilia") != nil {
                    let dv = vigilCommemoration(w, o, date, rite, true)
                    if !dv.isEmpty { ccind += 1; entries.append((Double(ccind + 8500), dv)) }
                }
                // The commemorations that office carries in its own file (an octave's).
                for d2 in fileCommemorations(w, o, hourSlug, cv, date, rite, ov) {
                    ccind += 1
                    let t = nameOf(d2)
                    entries.append((t.has(sunday, ci: true) ? 3000 : (t.has(octaveRe, ci: true) ? Double(ccind + 7900) : Double(ccind + 9900)), d2))
                }
            }
        }
        var ordered = entries.enumerated().sorted { a, b in a.element.0 != b.element.0 ? a.element.0 < b.element.0 : a.offset < b.offset }.map { $0.element.1 }
        // DO $octavam: an octave commemorated once only, whichever file names it.
        var seenOctaves = Set<String>()
        ordered = ordered.filter { m in
            let t = nameOf(m)
            if !t.has(octaveRe, ci: true) { return true }
            return seenOctaves.insert(t.lowercased().rreplace("\\s+", " ")).inserted
        }
        if lentSuppressed(o, hourSlug, date.dow, res.vespera) { ordered = ordered.map { $0.mapValues { withoutAlleluia($0) } } }
        // Under the 1960 rubrics a II-class day (or a II-class feria) keeps
        // only the first commemoration.
        if is1960(rite) && ordered.count > 1 && (o.rank >= 5 || (o.rankLine.containsCI("Feria") && o.rank >= 4)) { ordered = Array(ordered.prefix(1)) }
        return ordered
    }

    /// The commemoration a commemorated office's collect carries with it
    /// ("@File:CommemoratioN" after its Oratio: St Peter's on St Paul's).
    private func embeddedCommemorations(_ w: Office, _ ind: Int, _ winner: Office, _ hourSlug: String) -> [[String: Hour.Part]] {
        guard let sec = w.proper.sec("Oratio \(ind) Commemoratio") ?? w.proper.sec("Oratio Commemoratio") else { return [] }
        var out: [[String: Hour.Part]] = []
        for block in (sec.lat ?? "").rsplit("\\n(?=!)").filter({ !$0.isBlank }) {
            if hourSlug == "laudes" && block.has("precedenti|sequenti", ci: true) { continue }
            if let d = parseCommemorationBlock(block, nil, ind, winner) { out.append(d) }
        }
        return out
    }

    /// DO "add commemorated from commemo/cwinner": the commemorations a
    /// commemorated office carries in its own file (an octave's day).
    private func fileCommemorations(_ w: Office, _ winner: Office, _ hourSlug: String, _ cv: Int, _ date: LDate, _ rite: MissalRite, _ ov: Int = 0) -> [[String: Hour.Part]] {
        if (winner.rank >= 6 && !winner.dayName.has("Pasc[07]")) || winner.ruleHas("no commemoratio") ||
            (is1960(rite) && w.ruleHas("nocomm1960")) { return [] }
        var ind = cv
        var secOpt: Hour.Part? = w.proper.sec("Commemoratio \(cv)")
        if secOpt == nil && ov != 0, let s = w.proper.sec("Commemoratio \(ov)") { secOpt = s; ind = ov }
        if secOpt == nil, let s = w.proper.sec("Commemoratio"),
           cv != 3 || w.temporal || (s.lat ?? "").has("(O[ckt]t[aá]|Octava)", ci: true) { secOpt = s }
        guard var sec = secOpt else { return [] }
        // "Substitute Commemorated Octave to Vesp-$octvespera".
        if ov != 0 && (sec.lat ?? "").has("!.*?(O[ckt]t[aá]|Octava)", ci: true) {
            sec = w.proper.sec("Commemoratio \(ov)") ?? w.proper.sec("Commemoratio \(4 - ov)") ?? w.proper.sec("Commemoratio") ?? sec
            ind = ov
        }
        return commemorationBlocks(sec, w, winner, hourSlug, ind, date, rite)
    }

    /// DO "add commemorated from winner": commemorations the office file
    /// carries itself ([Commemoratio], [Commemoratio 1/2/3]).
    private func ownCommemorations(_ o: Office, _ hourSlug: String, _ vespera: Int, _ date: LDate, _ rite: MissalRite, _ ov: Int = 0) -> [[String: Hour.Part]] {
        var ind = hourSlug == "laudes" ? 2 : vespera
        if (o.rank >= 6 && !o.dayName.has("Pasc[07]|Pent01")) || (is1960(rite) && o.ruleHas("nocomm1960")) { return [] }
        var secOpt: Hour.Part? = o.proper.sec("Commemoratio \(ind)")
        if secOpt == nil, let s = o.proper.sec("Commemoratio"),
           ind != 3 || o.temporal || (s.lat ?? "").has("!.*O[ckt]ta", ci: true) { secOpt = s }
        guard var sec = secOpt else { return [] }
        // "Substitute Commemorated Octave to Vesp-$octvespera".
        if ov != 0 && (sec.lat ?? "").has("!.*?(O[ckt]t[aá]|Octava)", ci: true) {
            sec = o.proper.sec("Commemoratio \(ov)") ?? o.proper.sec("Commemoratio \(4 - ov)") ?? o.proper.sec("Commemoratio") ?? sec
            ind = ov
        }
        return commemorationBlocks(sec, o, o, hourSlug, ind, date, rite)
    }

    /// The "!Commemoratio ..." blocks of a section, filtered as DO does.
    private func commemorationBlocks(_ sec: Hour.Part, _ w: Office, _ winner: Office, _ hourSlug: String, _ ind: Int, _ date: LDate, _ rite: MissalRite) -> [[String: Hour.Part]] {
        let o = w
        let octave = "^!.*?(O[ckt]t[aá]|Octava)"
        let sunday = "^!.*?Dominic[aæ]"
        let nooctnat = is1955or1960(rite) && (date.month < 12 || date.day < 25)
        var out: [[String: Hour.Part]] = []
        let latBlocks = (sec.lat ?? "").rsplit("\\n(?=!)").filter { !$0.isBlank }
        let engBlocks = (sec.eng ?? "").rsplit("\\n(?=!)")
        for (i, block) in latBlocks.enumerated() {
            var refTitle = ""
            if let m = block.rmatch("(?m)^@([^:\\n]+):Oratio") {
                refTitle = "!" + officeFromKey(communeRef(m[1]), date, rite).rankLine.before(";;")
            }
            if (block.has(octave, ci: true) || block.has(sunday, ci: true) || refTitle.has(octave, ci: true) || refTitle.has(sunday, ci: true)) && nooctnat { continue }
            if is1955or1960(rite) && block.has("^!.*?Vigil", ci: true) && o.sanctoral && !o.key.has("08-14|06-23|06-28|08-09") { continue }
            if let d = parseCommemorationBlock(block, i < engBlocks.count ? engBlocks[i] : nil, ind, winner) { out.append(d) }
        }
        return out
    }

    /// DO getrefs "@File:Oratio": the commemoration of that office built
    /// from its file and commune (antiphon, versicle, collect).
    private func refCommemoration(_ file: String, _ ind: Int, _ o: Office) -> [String: Hour.Part]? {
        let rite = o.rite
        let key = communeRef(file)
        let w = officeFromKey(key, o.date, rite, dayName: o.dayName)
        var c: Src? = nil
        let rp = w.rankLine.components(separatedBy: ";;").map { $0.trimmed }
        if let m = (rp.count > 3 ? rp[3] : "").rmatch("(ex|vide)\\s+(.*?)\\s*$", ci: true) {
            var f = m[2].trimmed
            if f.has("^C[1-3]a?$") && o.dayName.hasPrefix("Pasc") { f += "p" }
            var src = srcFor(communeRef(f), rite)
            let chain = riteRules(rite)[f]?.rankLine?.rmatch(";;(ex|vide)\\s+(.*?)\\s*$", ci: true)
            if let s = src, let chain {
                var f2 = chain[2].trimmed
                if f2.has("^C[1-3]a?$") && o.dayName.hasPrefix("Pasc") { f2 += "p" }
                if let s2 = srcFor(communeRef(f2), rite) {
                    let keep: Set<String> = ["Oratio", "Ant 1", "Ant 2", "Ant 3", "Versum 1", "Versum 2", "Versum 3"]
                    var parts = s2.parts.filter { keep.contains($0.key) }
                    parts.merge(s.parts) { _, n in n }
                    src = Src(parts: parts, doKeyed: true, psalmi: s.psalmi)
                }
            }
            c = src
        }
        let a = antSec(w.proper, "Ant \(ind)") ?? c.flatMap { antSec($0, "Ant \(ind)") }
        var v = w.proper.sec("Versum \(ind)") ?? c?.sec("Versum \(ind)")
        if v == nil && w.temporal {
            let name = tempora("getfrompsalterium major", o, o.date.dow, rite) + " Versum"
            v = psalt("\(name) \(ind)") ?? psalt("\(name) 1") ?? psalt("\(name) 3") ?? psalt("\(name) 2")
        }
        guard let orp = (w.proper.sec("Oratio") ?? c?.sec("Oratio")).map({ withName($0, w.proper) }) else { return nil }
        var out: [String: Hour.Part] = [:]
        out["name"] = { var p = Hour.Part(type: "rubric"); p.lat = rp.first ?? w.name; return p }()
        if let a {
            var ap = a.withType("antiphon")
            ap.lat = lines(a).first; ap.eng = engLines(a).first; ap.variationKey = nil
            out["ant_\(ind)"] = withName(ap, w.proper)
        }
        if let v { out["versum_\(ind)"] = vrFrom(v, "versum_\(ind)") }
        var op = orp.withType("collect")
        op.label = "Oratio"; op.variationKey = "oratio"
        out["oratio"] = op
        return out
    }

    /// "!Title / Ant. … / _ / V. … / R. … / _ / $Oremus / collect".
    private func parseCommemorationBlock(_ lat: String, _ eng: String?, _ ind: Int, _ o: Office) -> [String: Hour.Part]? {
        let ll = lat.lines.map { $0.trimmed }.filter { !$0.isEmpty }
        let el = (eng ?? "").lines.map { $0.trimmed }.filter { !$0.isEmpty }
        let title = ll.first { $0.hasPrefix("!") }?.dropPrefix("!").trimmed ?? ""
        func titled(_ d: [String: Hour.Part]) -> [String: Hour.Part] {
            var m = d
            if !title.isEmpty { var p = Hour.Part(type: "rubric"); p.lat = title.dropPrefix("Commemoratio").trimmed; m["name"] = p }
            return m
        }
        if let ref = ll.first(where: { $0.has("^@[^:]+:Oratio") }) {
            let file = ref.after("@").before(":")
            guard let d = refCommemoration(file, ind, o) else { return nil }
            return titled(d)
        }
        // DO getrefs "@File:Octava": the octave's own commemoration block
        // ([Octava], else [Octava N] by the Vespers, else the other one).
        if let ref = ll.first(where: { $0.has("^@[^:]+:Octava", ci: true) }) {
            let file = ref.after("@").before(":")
            guard let src = srcFor(communeRef(file), o.rite) else { return nil }
            guard let sec = src.sec("Octava") ?? src.sec("Octava \(ind)") ?? src.sec("Octava \(ind == 2 ? 1 : 2)") else { return nil }
            guard let d = parseCommemorationBlock(sec.lat ?? "", sec.eng, ind, o) else { return nil }
            return titled(d)
        }
        let ant = ll.first { $0.hasPrefix("Ant.") }?.dropPrefix("Ant.").trimmed
        let antE = el.first { $0.hasPrefix("Ant.") }?.dropPrefix("Ant.").trimmed
        let v = ll.first { $0.hasPrefix("V.") || $0.hasPrefix("℣.") }.map { "℣. " + String($0.dropFirst(2)).trimmed }
        let r = ll.first { $0.hasPrefix("R.") || $0.hasPrefix("℟.") }.map { "℟. " + String($0.dropFirst(2)).trimmed }
        let vE = el.first { $0.hasPrefix("V.") || $0.hasPrefix("℣.") }.map { "℣. " + String($0.dropFirst(2)).trimmed }
        let rE = el.first { $0.hasPrefix("R.") || $0.hasPrefix("℟.") }.map { "℟. " + String($0.dropFirst(2)).trimmed }
        func collect(_ lines: [String]) -> String {
            let i = lines.firstIndex { $0.hasPrefix("$Oremus") }
            let rest = Array(lines.dropFirst(i.map { $0 + 1 } ?? 0))
            return rest.filter { !$0.hasPrefix("$") && !$0.hasPrefix("!") && !$0.hasPrefix("_") && !$0.hasPrefix("Ant.") && !$0.hasPrefix("V.") && !$0.hasPrefix("R.") }
                .map { $0.dropPrefix("v. ") }.joined(separator: "\n")
        }
        let oratio = collect(ll)
        if oratio.isBlank { return nil }
        let paschal = alleluiaRequired(o.dayName)
        var out: [String: Hour.Part] = [:]
        out["name"] = { var p = Hour.Part(type: "rubric"); p.lat = title.dropPrefix("Commemoratio").trimmed; return p }()
        if let ant {
            var p = Hour.Part(type: "antiphon"); p.lat = ant; p.eng = antE
            out["ant_\(ind)"] = withInlineAlleluia(withName(p, o.proper), paschal)
        }
        if let v {
            var p = Hour.Part(type: "vr"); p.label = "Versicle"; p.lat = v; p.latR = r; p.eng = vE; p.engR = rE; p.variationKey = "versum_\(ind)"
            out["versum_\(ind)"] = withInlineAlleluia(p, paschal)
        }
        var op = Hour.Part(type: "collect"); op.label = "Oratio"; op.lat = oratio
        let ce = collect(el); op.eng = ce.isBlank ? nil : ce
        op.variationKey = "oratio"
        out["oratio"] = withInlineAlleluia(withName(op, o.proper), paschal)
        return out
    }

    /// An office known only by its DO key (a commemoration).
    func officeFromKey(_ key: String, _ date: LDate, _ rite: MissalRite, tomorrow: Bool = false, dayName: String = "") -> Office {
        let rr = riteRules(rite)
        let k = key.after(":")
        let rule = rr[k] ?? rr[k.take(5)]
        // DO officestring: a Pent/Epi office (not Pent01-05) takes the
        // scripture-cycle file of the date (the following day's at I Vespers).
        let md: String? = (key.has("^tempora:(pent|epi)") && !key.has("^tempora:pent0[1-5]"))
            ? ordoFor(rite, date).flatMap { tomorrow ? $0.m1 : $0.m0 } : nil
        // The scripture-cycle file carries the day's rank too (an Ember day).
        let mdRule = md.flatMap { rr[$0.after(":")] }
        var d = DoOffice(w: key)
        d.r = mdRule?.rank ?? rule?.rank ?? 0
        d.d = dayName
        d.n = mdRule?.rankLine ?? rule?.rankLine ?? ""
        d.c = rule?.commune
        d.t = rule?.communeType
        d.md = md
        return officeFrom(d, tomorrow ? date.plusDays(1) : date, rite)
    }

    /// DO's Lauds scheme: 2 (Ps 50) on penitential ferias, else 1.
    private func laudesScheme(_ o: Office, _ dow: Int, _ rite: MissalRite) -> Int {
        if let l = o.laudesDO { return l }
        let dn = o.dayName
        let penitential = ((dn.hasPrefix("Adv") && dow != 0) || dn.hasPrefix("Quad") ||
            (emberDay(o, dow) && !dn.hasPrefix("Pasc"))) && o.temporal && !o.rankHas("(Beatæ|Sanctæ) Mariæ")
        return (penitential || o.ruleHas("Laudes 2") ||
            (o.rankHas("vigil") && !is1955or1960(rite) && !o.ruleHas("Psalmi Dominica"))) ? 2 : 1
    }

    struct Concurrence {
        let office: Office
        let vespera: Int
        let commemoration: Office?
        let commemorationVespera: Int
    }

    /// DO concurrence (1960 rules, with the older branches where they
    /// differ): whether Vespers is of the following office.
    func concurrence(_ today: Office, _ tomorrow: Office?, _ dow: Int, _ rite: MissalRite) -> Concurrence {
        guard let tomorrow else { return Concurrence(office: today, vespera: 3, commemoration: nil, commemorationVespera: 0) }
        let crank = tomorrow.rank
        let rank = today.rank
        let cw = tomorrow
        let noFirst = cw.ruleHas("No prima vespera") ||
            (rite == .rite1955 && crank < 5) ||
            (is1960(rite) && crank < ((cw.isSunday || (cw.ruleHas("Festum Domini") && dow == 6)) ? 5.0 : 6.0)) ||
            (cw.rankHas("Feria|Sabbato|Vigilia|Quat[t]*uor") && !cw.rankHas("in Vigilia Epi|in octava|infra octavam|Dominica|C10")) ||
            (cw.rankHas("infra octavam|Vigilia Pent") && !cw.rankHas("Dominica") &&
                today.rankHas("infra octavam|post Octavam Asc|Quat.*Pent|Dominica (Resurrectionis|Pentecostes)")) ||
            ((today.dayName.hasPrefix("Pasc0") || today.dayName.hasPrefix("Pasc7")) && !cw.isSunday) ||
            (cw.isC10 && today.rankHas("C1[01]")) ||
            (is1955or1960(rite) && cw.rankHas("Dominica Resurrectionis|Patrocinii S. Joseph")) ||
            (is1955or1960(rite) && cw.rankHas("octav") && !cw.rankHas("dominica|cum Octava") && crank < 6)
        if noFirst { return Concurrence(office: today, vespera: 3, commemoration: nil, commemorationVespera: 0) }
        if today.temporal && tomorrow.temporal && !cw.isC10 {
            return (crank >= rank || today.ruleHas("No secunda vespera"))
                ? Concurrence(office: tomorrow, vespera: 1, commemoration: nil, commemorationVespera: 0)
                : Concurrence(office: today, vespera: 3, commemoration: nil, commemorationVespera: 0)
        }
        let precTodayWins = (rank >= ((is1955or1960(rite) && dow < 6) ? 6.0 : 7.0) && crank < 6) ||
            (is1960(rite) && cw.isSunday && !today.dayName.hasPrefix("Nat1") && crank <= 5 && rank >= 5 && today.ruleHas("Festum Domini")) ||
            (rank >= 5 && !today.rankHas("feria|in.*octava") && crank < 2.1)
        if precTodayWins { return Concurrence(office: today, vespera: 3, commemoration: nil, commemorationVespera: 0) }
        let privileged = rank == 1.15 || rank == 2.1 || rank == 2.99 || rank == 3.9
        let tomorrowWins = (rank < 2 && !(rank == 1.15 && today.temporal)) ||
            (is1960(rite) && (cw.isSunday || cw.ruleHas("Festum Domini")) &&
                (rank < (crank >= 6 ? 6.0 : 5.0) || today.isSunday || today.ruleHas("Festum Domini"))) ||
            (crank >= 6 && !(privileged || rank >= 4.2) && !cw.rankHas("Dominica|feria|in.*octava")) ||
            (cw.key == "12-25" || cw.key == "01-01") ||
            (crank >= 5 && !(rank == 1.15 || rank == 2.1 || rank >= 2.99) && !cw.rankHas("Dominica|feria|in.*octava"))
        if tomorrowWins {
            let commem = (privileged && cw.key != "12-25" && cw.key != "01-01") ? today : nil
            return Concurrence(office: tomorrow, vespera: 1, commemoration: commem, commemorationVespera: 3)
        }
        if is1960(rite) && rank >= crank { return Concurrence(office: today, vespera: 3, commemoration: tomorrow, commemorationVespera: 1) }
        if crank > rank { return Concurrence(office: tomorrow, vespera: 1, commemoration: today, commemorationVespera: 3) }
        return Concurrence(office: today, vespera: 3, commemoration: tomorrow, commemorationVespera: 1)
    }

    // MARK: resolve

    func resolve(_ hourSlug: String, _ date: LDate, _ dow: Int, _ ordo: OrdoEntry?, _ tomorrow: OrdoEntry?, _ rite: MissalRite) -> Resolution? {
        riteCtx = rite
        let doDay = ordoFor(rite, date)
        if ordo == nil && doDay?.l == nil { return nil }
        let today: Office = doDay?.l.map { officeFrom($0, date, rite) } ?? officeFor(ordo!, date, rite)
        var office = today
        var vespera = 3
        var commem: Office? = nil
        var commemVespera = 0
        if hourSlug == "vesperae" || hourSlug == "completorium" {
            if let dv = doDay?.v {
                vespera = dv.vs ?? 3
                office = officeFrom(dv, vespera == 1 ? date.plusDays(1) : date, rite)
                if let cv = dv.cv { commem = officeFromKey(cv, vespera == 1 ? date : date.plusDays(1), rite) }
                commemVespera = vespera == 1 ? 3 : 1
            } else {
                let tom = tomorrow.map { officeFor($0, date.plusDays(1), rite) }
                let c = concurrence(today, tom, dow, rite)
                office = c.office
                vespera = c.vespera
                commem = c.commemoration
                commemVespera = c.commemorationVespera
            }
        }
        let o = office
        let laudes = laudesScheme(today, dow, rite)
        var out: [String: Hour.Part] = [:]
        var drop = Set<String>()
        var nocturns = 1
        var lessons = 3
        var teDeum = false

        switch hourSlug {
        case "laudes", "vesperae": psalmiMajor(hourSlug, o, dow, laudes, vespera, rite, &out)
        case "prima", "tertia", "sexta", "nona", "completorium": psalmiMinor(hourSlug, o, dow, laudes, rite, &out, &drop)
        case "matutinum":
            let r = psalmiMatutinum(o, dow, laudes, rite, &out, &drop)
            nocturns = r.0; lessons = r.1
            teDeum = teDeumRequired(o, dow, lessons, rite)
        default: break
        }
        if hourSlug == "laudes" || hourSlug == "vesperae" {
            capitulumMajor(hourSlug, o, dow, vespera, rite, &out)
            hymnusMajor(hourSlug, o, dow, vespera, rite, &out)
            versumMajor(hourSlug, o, dow, vespera, rite, &out)
            canticleAntiphon(hourSlug, o, dow, vespera, rite, &out, date)
        }
        if ["tertia", "sexta", "nona"].contains(hourSlug) {
            capitulumMinor(hourSlug, o, dow, rite, &out)
            hymnusMinor(hourSlug, o, &out)
        }
        if hourSlug == "prima" { primaPieces(o, dow, rite, &out) }
        if hourSlug == "completorium" { complinePieces(o, dow, vespera, rite, &out) }
        if hourSlug == "matutinum" {
            invitatorium(o, dow, rite, &out)
            hymnusMatutinum(o, dow, rite, &out)
        }
        func dropKeys(_ keys: [String]) { for k in keys { out.removeValue(forKey: k); drop.insert(k) } }
        // "Omit ... Hymnus" (the Easter and Pentecost octaves, the Triduum).
        if o.ruleHas("Omit ad Matutinum[^\n]*Hymnus") {
            dropKeys(["hymnus_matutinum"])
        } else if o.ruleHas("Omit(?! ad )[^\n]*Hymnus") {
            dropKeys(["hymnus_matutinum", "hymnus_laudes", "hymnus_vespera", "prima.hymn", "tertia.hymn", "sexta.hymn", "nona.hymn", "completorium.hymn"])
        }
        if hourSlug == "matutinum" && (o.ruleHas("Omit ad Matutinum[^\n]*Invitatorium") || o.ruleHas("Omit(?! ad )[^\n]*Invitatorium")) {
            dropKeys(["invit"])
        }
        // "Omit ... Capitulum" (the Triduum): no capitulum, responsory or versicle.
        if o.ruleHas("Omit(?! ad )[^\n]*Capitulum") {
            dropKeys(["capitulum_laudes", "vesperae.capitulum", "tertia.capitulum", "capitulum_sexta", "capitulum_nona", "prima.capitulum",
                      "completorium.capitulum", "responsory_breve_tertia", "responsory_breve_sexta", "responsory_breve_nona", "prima.responsory",
                      "completorium.responsory", "versum_1", "versum_2", "versum_tertia", "versum_sexta", "versum_nona", "versum_prima"])
        }
        // "Capitulum Versum 2": the proper's Versum 2 ("Hæc dies") stands in
        // place of the capitulum, and the short responsory and versicle go.
        let cv2 = o.rule.rmatch("Capitulum Versum 2( ad Laudes tantum| ad Laudes et Vesperas)?", ci: true)
        var cv2Applies = false
        if let cv2, hourSlug != "matutinum" {
            switch cv2[1].trimmed.lowercased() {
            case "ad laudes tantum": cv2Applies = hourSlug == "laudes"
            case "ad laudes et vesperas": cv2Applies = hourSlug == "laudes" || hourSlug == "vesperae"
            default: cv2Applies = true
            }
        }
        if cv2Applies && hourSlug == "completorium" {
            // DO: at Compline the capitulum (with its short responsory and
            // versicle) is simply omitted; the verse comes with the canticle.
            if out["completorium.capitulum"]?.label != "In loco Capituli" { dropKeys(["completorium.capitulum"]) }
            dropKeys(["completorium.responsory", "versum_completorium"])
        } else if cv2Applies {
            let v2 = proprium(o, "Versum 2", true)
            let capKey: String
            switch hourSlug {
            case "laudes": capKey = "capitulum_laudes"; case "vesperae": capKey = "vesperae.capitulum"; case "tertia": capKey = "tertia.capitulum"
            case "sexta": capKey = "capitulum_sexta"; case "nona": capKey = "capitulum_nona"; case "prima": capKey = "prima.capitulum"
            default: capKey = "completorium.capitulum"
            }
            drop.remove(capKey)
            if let v2 {
                if v2.latR != nil || (lines(v2).first?.hasPrefix("℣") ?? false) {
                    var p = vrFrom(v2, capKey); p.label = "In loco Capituli"
                    out[capKey] = p
                } else {
                    let text = lines(v2).joined(separator: "\n").dropPrefix("Ant. ")
                    let eng = engLines(v2).joined(separator: "\n").dropPrefix("Ant. ")
                    var p = Hour.Part(type: "antiphon"); p.label = "In loco Capituli"; p.lat = text; p.eng = eng.isBlank ? nil : eng; p.variationKey = capKey
                    out[capKey] = p
                }
            }
            let candidates = ["responsory_breve_\(hourSlug)", "versum_\(hourSlug)", "prima.responsory", "versum_prima", "completorium.responsory", "versum_1", "versum_2"]
            let toDrop = candidates.filter { it in
                (it.hasPrefix("versum_") && ((hourSlug == "laudes" && it == "versum_1") || (hourSlug == "vesperae" && it == "versum_2") || it == "versum_\(hourSlug)")) ||
                it == "responsory_breve_\(hourSlug)" || (hourSlug == "prima" && it.hasPrefix("prima.")) || (hourSlug == "prima" && it == "versum_prima") ||
                (hourSlug == "completorium" && it == "completorium.responsory")
            }
            dropKeys(toDrop)
        }
        // The collect of the day, when the office carries its own.
        if ["matutinum", "laudes", "tertia", "sexta", "nona", "vesperae"].contains(hourSlug) {
            if let c = oratioOf(o, hourSlug, vespera, dow), !c.lat.isNullOrBlank {
                var p = c.withType("collect"); p.label = "Oratio"; p.variationKey = "oratio"
                out["oratio"] = p
            }
        }
        // The Triduum's Prime: psalms, then "Christus factus est", the Pater
        // noster and the collect; no capitulum, chapter office or blessing.
        if hourSlug == "prima" && o.ruleHas("Omit(?! ad )[^\n]*Capitulum") && o.ruleHas("Omit(?! ad )[^\n]*Martyrologium") {
            dropKeys(["prima2.heading", "prima2.martyrologium", "prima2.pretiosa", "prima2.sanctamaria", "prima2.deusinadjutorium",
                      "prima2.pater", "prima2.respice", "prima2.oratio", "prima2.benedictio1", "lectio_prima", "prima2.tuautem",
                      "prima2.adjutorium", "prima2.benedictio2", "versum_prima", "prima.hymn", "ant_prima"])
            if let c = oratioOf(o, "prima", vespera, dow), !c.lat.isNullOrBlank {
                var p = c.withType("collect"); p.label = "Oratio"; p.variationKey = "oratio_prima"
                out["oratio_prima"] = p
            }
        }
        // The office's name for its "N.", and the bracketed alleluias.
        let paschalNow = alleluiaRequired(o.dayName)
        for (k, v) in out { out[k] = withInlineAlleluia(withName(v, o.proper), paschalNow) }
        // Septuagesima to Holy Saturday: every alleluia goes (DO suppress_alleluia).
        if lentSuppressed(o, hourSlug, dow, vespera) { for (k, v) in out { out[k] = withoutAlleluia(v) } }
        // Paschaltide: the alleluias DO appends to versicles and short responsories.
        if alleluiaRequired(o.dayName) && !o.ruleHas("C9|C12") {
            for (k, v) in out {
                if k.hasPrefix("versum_") || k.hasPrefix("nocturn_") { out[k] = alleluiaVersicle(v) }
                else if k.hasPrefix("responsory_breve_") || k == "prima.responsory" || k == "completorium.responsory" { out[k] = alleluiaResponsory(v) }
            }
        }
        let precesOffice = (hourSlug == "vesperae" || hourSlug == "completorium") ? o : today
        let pfAll = precesFeriales(precesOffice, dow, hourSlug, rite)
        // The 1955 and 1960 books keep the ferial preces at Lauds and Vespers only.
        let pf = pfAll && (rite == .pre1955 || hourSlug == "laudes" || hourSlug == "vesperae")
        let pd = rite == .pre1955 && (hourSlug == "prima" || hourSlug == "completorium") && precesDominicales(precesOffice, commem, rite)
        let precesParts = rite == .pre1955 ? precesScript(o, hourSlug, pf, pd, dow) : nil
        // The Vigil of Pentecost closes Paschaltide at None: Compline already takes the Salve Regina.
        let marian: String? = (hourSlug == "completorium" && today.dayName == "Pasc7" && dow == 6) ? "salve-regina" : nil
        // DO's own commemoration list for the hour (already filtered by its rubrics).
        let cms: [String] = (hourSlug == "vesperae" || hourSlug == "completorium") ? (doDay?.v?.cm ?? []) : today.commemorations
        let omitRe = hourSlug == "matutinum" ? "Omit (ad Matutinum )?[^\n]*" : "Omit(?! ad )[^\n]*"
        let omitIncipit = o.ruleHas("\(omitRe)Incipit")
        let omitConclusion = o.ruleHas("\(omitRe)Conclusion")
        var special: [Hour.Part]? = specialHour(o, hourSlug, vespera, dow)?.map { withInlineAlleluia(withName($0, o.proper), paschalNow) }
        // All Saints' evening in the older books: Compline of the Dead (DO "die Omnium Defunctorum").
        if special == nil && rite == .pre1955 && hourSlug == "completorium" && date.month == 11 && date.day == 1 && dow != 6 {
            if let sec = propersFor(rite)["sancti:11-02"]?.parts["Special Completorium"] {
                let dead = officeFromKey("sancti:11-02", date, rite)
                special = renderScript(sec, dead, hourSlug, dow)
            }
        }
        if lentSuppressed(o, hourSlug, dow, vespera) { special = special?.map { withoutAlleluia($0) } }
        let conclusio: [Hour.Part]? = (special == nil && o.ruleHas("Special Conclusio")) ? o.proper.sec("Conclusio").map { renderScript($0, o, hourSlug, dow) } : nil
        let append = litania(o, hourSlug, date, rite, dow)
        // A psalm inside the collect script (the Triduum's Miserere) goes before it.
        var beforeCollect: [Hour.Part] = []
        for ck in ["oratio", "oratio_prima"] {
            guard let c = out[ck] else { continue }
            let ls = (c.lat ?? "").lines
            if !ls.contains(where: { $0.hasPrefix("&psalm(") }) { continue }
            for l in ls where l.hasPrefix("&psalm(") {
                guard let n = Int(l.after("(").before(")").before(",").trimmed) else { continue }
                var p = Hour.Part(type: "psalm"); p.label = "Psalmus \(n)"; p.ref = "Ps \(n)"
                beforeCollect.append(p)
            }
            var nc = c
            nc.lat = ls.filter { !$0.hasPrefix("&psalm(") }.joined(separator: "\n")
            nc.eng = c.eng?.lines.filter { !$0.hasPrefix("&psalm(") }.joined(separator: "\n")
            out[ck] = nc
        }
        let suffragium = suffragium(o, hourSlug, dow, rite, commem)
        return Resolution(overrides: out, drop: drop, office: o, vespera: vespera, nocturns: nocturns, lessons: lessons, teDeum: teDeum,
                          precesFeriales: pf, precesDominicales: pd, commemoration: commem, commemorationVespera: commemVespera,
                          laudes: laudes, marianOverride: marian, commemorations: cms, fromDO: doDay?.l != nil,
                          omitIncipit: omitIncipit, omitConclusion: omitConclusion, conclusio: conclusio, special: special, append: append,
                          preces: precesParts, beforeConclusion: suffragium, beforeCollect: beforeCollect,
                          marianAfterLauds: rite == .pre1955 && hourSlug == "laudes" && special == nil && append.isEmpty && conclusio == nil)
    }

    // MARK: DO scripts (Special hours, conclusions, the Litany)

    /// The "Special <Hour>" script of the office, if it carries one (All
    /// Souls' little hours and Compline, the Triduum's Compline, the Easter
    /// Vigil's Vespers).
    private func specialHour(_ o: Office, _ hourSlug: String, _ vespera: Int, _ dow: Int) -> [Hour.Part]? {
        let h: String
        switch hourSlug {
        case "prima": h = "Prima"; case "tertia": h = "Tertia"; case "sexta": h = "Sexta"; case "nona": h = "Nona"
        case "completorium": h = "Completorium"; case "vesperae": h = "Vespera"; case "laudes": h = "Laudes"
        default: return nil
        }
        guard let sec = (hourSlug == "vesperae" ? o.proper.sec("Special Vespera \(vespera)") : nil) ?? o.proper.sec("Special \(h)") else { return nil }
        let parts = renderScript(sec, o, hourSlug, dow)
        return parts.isEmpty ? nil : parts
    }

    /// DO checksuffragium.
    private func suffragiumApplies(_ o: Office, _ commem: Office?) -> Bool {
        let dn = o.dayName
        if o.ruleHas("no suffragium") || dn.isEmpty { return false }
        if dn.has("Nat05|Quad6|Pasc[067]") { return false }
        if dn.has("Adv|Nat|Quad5") { return false }
        if o.sanctoral && o.rank >= 3 { return false }
        if o.temporal && o.duplex > 2 { return false }
        if o.rankHas("octav") && !o.rankHas("post Octavam") { return false }
        func checkCommemoratio(_ w: Office) -> String {
            w.proper.sec("Commemoratio")?.lat?.blankToNil
                ?? w.proper.sec("Commemoratio 1")?.lat?.blankToNil ?? w.proper.sec("Commemoratio 2")?.lat?.blankToNil
                ?? w.proper.sec("Commemoratio 3")?.lat ?? ""
        }
        func blocks(_ w: Office) -> Bool { w.rank >= 3 || w.rankHas("in.*Octav") || checkCommemoratio(w).containsCI("octav") }
        let first = commem ?? o.commemoratioKey.map { officeFromKey($0, o.date, o.rite) }
        if let first {
            if blocks(first) { return false }
            for ck in o.commemorations + o.commemorations1 { if blocks(officeFromKey(ck, o.date, o.rite)) { return false } }
        }
        return true
    }

    /// DO getsuffragium: the suffrage of all the saints after the collects
    /// at Lauds and Vespers (the Divino Afflatu books).
    private func suffragium(_ o: Office, _ hourSlug: String, _ dow: Int, _ rite: MissalRite, _ commem: Office?) -> [Hour.Part] {
        if rite != .pre1955 || (hourSlug != "laudes" && hourSlug != "vesperae") { return [] }
        if !suffragiumApplies(o, commem) { return [] }
        let dn = o.dayName
        let bvm = o.isC10 || (o.communeKey?.has("^C1[012]") ?? false)
        guard let sec = psalt(dn.hasPrefix("Pasc") ? "Suffragium Paschale" : (bvm ? "Suffragium Divino1" : "Suffragium")) else { return [] }
        let parts = renderScript(sec, o, hourSlug, dow)
        if parts.isEmpty { return [] }
        var h = Hour.Part(type: "heading"); h.label = "Suffragium"
        return [h] + parts
    }

    /// The Litany of the Saints after Lauds (St Mark's day; the Rogation
    /// days in the older books), as DO appends it.
    private func litania(_ o: Office, _ hourSlug: String, _ date: LDate, _ rite: MissalRite, _ dow: Int) -> [Hour.Part] {
        if hourSlug != "laudes" { return [] }
        let rr = riteRules(rite)
        let has = o.ruleHas("Laudes Litania") ||
            (rr["\(o.dayName.lowercased())-\(dow)"]?.rule?.containsCI("Laudes Litania") ?? false) ||
            o.commemorations.contains { rr[$0.after(":")]?.rule?.containsCI("Laudes Litania") ?? false } ||
            (o.mdKey.flatMap { propersFor(rite)[$0]?.parts["Rule"]?.lat?.containsCI("Laudes Litania") } ?? false)
        if !has || !(date.month == 4 || !is1960(rite)) { return [] }
        guard let lit = psalt("Litania") else { return [] }
        var out: [Hour.Part] = []
        if let p = psalt("Prayer Domine exaudi") { out += vrPairs(p) }
        if let p = psalt("Prayer Benedicamus Domino") { out += vrPairs(p) }
        out += renderScript(lit, o, hourSlug, dow).map { p in
            if p.type == "psalm" { var n = p; n.variationKey = "litania.psalm"; return n }
            return p
        }
        return out
    }

    private func stripPrefix(_ l: String) -> String { l.rreplace("^(v\\.|r\\.|V\\.|R\\.|℣\\.|℟\\.)\\s*", "").trimmed }

    /// "V. … / R. …" lines of a prayer as ℣/℟ parts.
    private func vrPairs(_ p: Hour.Part, _ label: String = "Versus") -> [Hour.Part] {
        let ll = lines(p).filter { !$0.hasPrefix("/:") && !$0.hasPrefix("&") && !$0.hasPrefix("$") }
        let el = engLines(p).filter { !$0.hasPrefix("/:") && !$0.hasPrefix("&") && !$0.hasPrefix("$") }
        var out: [Hour.Part] = []
        var i = 0
        var j = 0
        while i < ll.count {
            let v = ll[i]; i += 1
            var r: String? = nil
            if i < ll.count && ll[i].has("^(R\\.|℟\\.)") { r = ll[i]; i += 1 }
            let ve: String? = j < el.count ? el[j] : nil
            if ve != nil { j += 1 }
            var re: String? = nil
            if r != nil, j < el.count { re = el[j]; j += 1 }
            var part = Hour.Part(type: "vr")
            part.label = label
            part.lat = "℣. " + stripPrefix(v)
            part.latR = r.map { "℟. " + stripPrefix($0) }
            part.eng = ve.map { "℣. " + stripPrefix($0) }
            part.engR = re.map { "℟. " + stripPrefix($0) }
            out.append(part)
        }
        return out
    }

    /// A "$Name" prayer of a script: the psalterium's common prayer.
    private func prayerParts(_ name: String, _ o: Office, _ last: Hour.Part?) -> ([Hour.Part], Bool) {
        switch name {
        case "Oremus": var h = Hour.Part(type: "heading"); h.label = "Orémus."; return ([h], false)
        case "Amen": return ([], false)
        default: break
        }
        if name.hasPrefix("rubrica ") { var h = Hour.Part(type: "heading"); h.label = name.dropPrefix("rubrica ").trimmed; return ([h], false) }
        guard let p = psalt("Prayer \(name)") else { return ([], false) }
        let ll = lines(p).filter { !$0.hasPrefix("/:") && !$0.hasPrefix("!") && !$0.hasPrefix("&") && !$0.hasPrefix("$") }
        if ll.isEmpty { return ([], false) }
        if ll.allSatisfy({ $0.has("^(V\\.|R\\.|℣\\.|℟\\.)") }) { return (vrPairs(p), false) }
        // A conclusion ("Per Dóminum …") joins the collect before it.
        if name.hasPrefix("Per ") || name.hasPrefix("Qui ") {
            if let last, last.type == "collect" {
                let lat = (last.lat ?? "") + "\n" + ll.map { stripPrefix($0) }.joined(separator: "\n")
                let eng = engLines(p).filter { !$0.hasPrefix("/:") }.map { stripPrefix($0) }.joined(separator: "\n")
                var n = last
                n.lat = lat
                n.eng = last.eng.map { eng.isBlank ? $0 : $0 + "\n" + eng }
                return ([n], true)
            }
        }
        let label: String
        switch name {
        case "Pater noster", "Pater noster Et", "pater secreto", "Pater totum secreto": label = "Pater noster"
        case "Ave Maria": label = "Ave María"; case "Credo": label = "Credo"; case "Confiteor": label = "Confíteor"
        case "Misereatur": label = "Misereátur"; case "Indulgentiam": label = "Indulgéntiam"
        default: label = name
        }
        let lat = ll.map { stripPrefix($0) }.joined(separator: "\n")
        let eng = engLines(p).filter { !$0.hasPrefix("/:") && !$0.hasPrefix("!") }.map { stripPrefix($0) }.joined(separator: "\n")
        var part = Hour.Part(type: "reading"); part.label = label; part.lat = lat; part.eng = eng.isBlank ? nil : eng
        return ([part], false)
    }

    /// A DO script (a "Special <Hour>" section, a Conclusio, the Litany)
    /// as parts: &psalm(N[,a,b]) psalms, $Prayer common prayers, Ant./V./R.
    /// lines, "v." collect lines, &special('X') pieces, headings and rubrics.
    private func renderScript(_ sec: Hour.Part, _ o: Office, _ hourSlug: String, _ dow: Int, depth: Int = 0) -> [Hour.Part] {
        if depth > 3 { return [] }
        let ll = (sec.lat ?? "").lines.map { $0.trimmed }
        let el = (sec.eng ?? "").lines.map { $0.trimmed }
        var engAnt = el.filter { $0.hasPrefix("Ant.") }
        var engV = el.filter { $0.has("^(V\\.|℣\\.)") }
        var engR = el.filter { $0.has("^(R\\.|℟\\.)") }
        var engPrayer = el.filter { $0.hasPrefix("v. ") }
        let markerRe = "^(Ant\\.|V\\.|R\\.|℣\\.|℟\\.|v\\.|r\\.|[#!$&_(])"
        var engPlain = el.filter { !$0.isEmpty && !$0.has(markerRe) }
        func pop(_ a: inout [String]) -> String? { a.isEmpty ? nil : a.removeFirst() }
        var out: [Hour.Part] = []
        var plain: [String] = []
        func flushPlain() {
            if plain.isEmpty { return }
            var e: [String] = []
            for _ in 0..<plain.count { if let x = pop(&engPlain) { e.append(x) } }
            var p = Hour.Part(type: "reading"); p.lat = plain.joined(separator: "\n")
            let ej = e.joined(separator: "\n"); p.eng = ej.isBlank ? nil : ej
            out.append(p)
            plain.removeAll()
        }
        let lineMarker = "^(Ant\\.|V\\.|R\\.|℣\\.|℟\\.|v\\.|r\\.|[#!$&(])"
        var i = 0
        while i < ll.count {
            let l = ll[i]; i += 1
            if l.isEmpty || l == "_" { if !plain.isEmpty { plain.append("") }; continue }
            if !(!l.isEmpty && !l.has(lineMarker)) { flushPlain() }
            if l.hasPrefix("#") || l.hasPrefix("!") {
                var h = Hour.Part(type: "heading"); h.label = String(l.dropFirst()).trimmed; out.append(h)
            } else if l.hasPrefix("$") {
                let (ps, replaces) = prayerParts(String(l.dropFirst()).trimmed, o, out.last)
                if replaces { out.removeLast() }
                out += ps
            } else if l.hasPrefix("&psalm(") {
                let args = l.after("(").before(")").components(separatedBy: ",").map { $0.trimmed }
                guard let n = Int(args[0]) else { continue }
                let range = args.count >= 3 ? ":\(args[1])-\(args[2])" : ""
                if n >= 210 {
                    var p = Hour.Part(type: "canticle"); p.label = "Canticum"; p.ref = "Cant \(n)"; out.append(p)
                } else {
                    var p = Hour.Part(type: "psalm"); p.label = "Psalmus \(n)" + (range.isEmpty ? "" : " (\(args[1])-\(args[2]))"); p.ref = "Ps \(n)\(range)"; out.append(p)
                }
            } else if l.hasPrefix("&special(") {
                let name = l.after("'").before("'")
                if name.hasPrefix("#") {
                    var h = Hour.Part(type: "heading"); h.label = "Martyrológium"; h.variationKey = "prima2.heading"; out.append(h)
                    var r = Hour.Part(type: "reading"); r.label = "Martyrológium"; r.variationKey = "prima2.martyrologium"; out.append(r)
                } else if let s = o.proper.sec(name) {
                    out += renderScript(s, o, hourSlug, dow, depth: depth + 1)
                }
            } else if l.hasPrefix("&Dominus_vobiscum") {
                if let p = psalt("Prayer Domine exaudi") { out += vrPairs(p) }
            } else if l.hasPrefix("&Gloria") {
                if let p = psalt(o.ruleHas("Requiem gloria") ? "Prayer Requiem" : "Prayer Gloria") { out += vrPairs(p) }
            } else if l.hasPrefix("&") || l.hasPrefix("(") {
                // rubrical conditions and other DO directives: nothing to print
            } else if l.hasPrefix("Ant.") {
                var p = Hour.Part(type: "antiphon"); p.label = "Antíphona"; p.lat = l.dropPrefix("Ant.").trimmed
                p.eng = pop(&engAnt)?.dropPrefix("Ant.").trimmed
                out.append(p)
            } else if l.has("^(V\\.|℣\\.)") {
                var r: String? = nil
                if i < ll.count && ll[i].has("^(R\\.|℟\\.)") { r = ll[i]; i += 1 }
                var p = Hour.Part(type: "vr"); p.label = "Versus"
                p.lat = "℣. " + stripPrefix(l); p.latR = r.map { "℟. " + stripPrefix($0) }
                p.eng = pop(&engV).map { "℣. " + stripPrefix($0) }
                p.engR = r != nil ? pop(&engR).map { "℟. " + stripPrefix($0) } : nil
                out.append(p)
            } else if l.has("^(R\\.|℟\\.)") {
                var p = Hour.Part(type: "vr"); p.label = "Responsum"; p.lat = "℟. " + stripPrefix(l)
                p.eng = pop(&engR).map { "℟. " + stripPrefix($0) }
                out.append(p)
            } else if l.hasPrefix("r. N."), let last = out.last, last.type == "collect" {
                // the titular's name ("atque beáto N.") continues the collect
                out.removeLast()
                var n = last; n.lat = (last.lat ?? "") + " " + l.dropPrefix("r.").trimmed
                out.append(n)
            } else if l.hasPrefix("v. ") || l.hasPrefix("r. ") {
                let prev = out.last
                let isOratio = prev != nil && prev!.type == "heading" && (prev!.label == "Orémus." || (prev!.label?.contains("altius") ?? false))
                var p = Hour.Part(type: isOratio ? "collect" : "reading")
                if isOratio { p.label = "Oratio" }
                p.lat = stripPrefix(l)
                p.eng = pop(&engPrayer).map { stripPrefix($0) }
                out.append(p)
            } else {
                plain.append(l)
            }
        }
        flushPlain()
        return out
    }

    // MARK: Lauds / Vespers psalms

    private func psalmiMajor(_ hour: String, _ o: Office, _ dow: Int, _ laudes: Int, _ vespera: Int, _ rite: MissalRite,
                             _ out: inout [String: Hour.Part]) {
        let isLauds = hour == "laudes"
        let name = isLauds ? "Laudes\(laudes)" : "Vespera"
        guard let base = psalmiLines("Day\(dow) \(name)") else { return }
        var antiphones: [AntLine]? = nil
        let day = o.date.day
        let month = o.date.month
        if isLauds && month == 12 && (17...23).contains(day) && dow > 0 {
            antiphones = psalmiLines("Day\(dow) Laudes3")
        }
        var w: [AntLine]? = nil
        var fromCommune = false
        let secHora = isLauds ? "Ant Laudes" : "Ant Vespera"
        // "A capitulo de sequenti": the preceding office's antiphons and psalms.
        if !isLauds, let ac = o.anteCapitulum { w = expand(ac) }
        if w == nil && !isLauds && vespera == 3 {
            w = antList(o.proper, "Ant Vespera 3")
            if w == nil && !hasSection(o.proper, "Ant Vespera") && o.communeType == "ex" {
                w = antList(o.commune, "Ant Vespera 3"); fromCommune = w != nil
            }
        }
        if w == nil { w = antList(o.proper, secHora) }
        if w == nil && o.communeType == "ex" {
            w = antList(o.commune, secHora); fromCommune = w != nil
        }
        if let w { antiphones = w }
        let psalmiDominica = antiphones != nil &&
            (o.ruleHas("Psalmi Dominica") || o.communeRuleAnyHas("Psalmi Dominica")) &&
            (antiphones?.first?.psalms ?? []).isEmpty && !o.ruleHas("Psalmi Feria")
        let p = psalmiDominica ? (psalmiLines("Day0 " + (isLauds ? "Laudes1" : "Vespera")) ?? base) : base
        let slots = isLauds ? ["\(hour).psalm1", "\(hour).psalm2", "\(hour).psalm3", "\(hour).canticle1", "\(hour).psalm4"]
            : (1...5).map { "\(hour).psalm\($0)" }
        var result: [AntLine] = []
        for i in 0..<5 {
            let pl: AntLine? = i < p.count ? p[i] : nil
            let al: AntLine? = (antiphones != nil && i < antiphones!.count) ? antiphones![i] : nil
            var psalms: [String] = (al?.psalms?.isEmpty == false ? al!.psalms! : nil) ?? pl?.psalms ?? []
            let ant = antiphones != nil ? al?.ant : pl?.ant
            let antEng = antiphones != nil ? al?.antEng : pl?.antEng
            if i == 4 && !isLauds && !o.ruleHas("no Psalm5") {
                let re3 = "Psalm5 ?Vespera3=(\\d+)"
                let re = "Psalm5 ?Vespera=(\\d+)"
                var n: String? = o.anteCapitulum5
                if n == nil && vespera == 3 {
                    n = o.rule.rmatch(re3, ci: true)?[1] ?? (fromCommune ? o.communeRule.rmatch(re3, ci: true)?[1] : nil)
                }
                if n == nil { n = o.rule.rmatch(re, ci: true)?[1] ?? (fromCommune ? o.communeRule.rmatch(re, ci: true)?[1] : nil) }
                if let n { psalms = [n] }
            }
            result.append(AntLine(ant: ant, antEng: antEng, psalms: psalms))
        }
        // Paschaltide: the psalms under one "Alleluia" antiphon.
        if alleluiaRequired(o.dayName) && (!hasSection(o.proper, secHora) || o.isC10) && o.communeType != "ex" {
            for i in result.indices {
                result[i] = i == 0 ? AntLine(ant: alleluiaAnt, antEng: alleluiaAntEng, psalms: result[i].psalms) : AntLine(ant: nil, antEng: nil, psalms: result[i].psalms)
            }
        }
        for i in 0..<5 {
            let l = result[i]
            guard let ps = l.psalms, !ps.isEmpty else { continue }
            out[slots[i]] = psalmPart(slots[i], ps, l.ant, l.antEng)
        }
    }

    // MARK: Little hours

    private let hourTitles: [String: String] = ["prima": "Prima", "tertia": "Tertia", "sexta": "Sexta", "nona": "Nona", "completorium": "Completorium"]

    private func psalmiMinor(_ hour: String, _ o: Office, _ dow: Int, _ laudes: Int, _ rite: MissalRite,
                             _ out: inout [String: Hour.Part], _ drop: inout Set<String>) {
        guard let hora = hourTitles[hour], let list = psalmiRaw("Minor \(hora)") else { return }
        var i = dow
        let psalmiDominicaRule = o.ruleHas("Psalmi\\s*(minores)*\\s*Dominica") ||
            (o.communeRuleHas("Psalmi\\s*(minores)*\\s*Dominica") && !o.ruleHas("Psalmi\\s*(?:minores)*\\s*ex Psalterio"))
        if psalmiDominicaRule { i = 0 }
        if is1955or1960(rite) && (o.ruleHas("horas1960 feria") || (o.sanctoral && o.rank < 5) ||
            ((o.sanctoral || o.dayName.has("^Nat[23]")) && o.rank < 6 && hour != "completorium")) {
            i = dow
        }
        if hour == "completorium" && dow == 6 && o.isSunday && !o.dayName.hasPrefix("Nat") { i = 6 }
        guard i < list.count else { return }
        var ant: String? = list[i].ant
        var antEng: String? = list[i].antEng
        var psalms: [String] = list[i].psalms ?? []
        if (is1960(rite) && psalms.contains("117") && laudes == 2) || o.ruleHas("Prima=53") {
            psalms = psalms.map { $0 == "117" ? "53" : $0 }
        }
        if hour == "completorium" {
            if o.temporal && dow > 0 && o.isSunday && o.rank < 6 {
                // A Sunday office on a weekday keeps the ferial Compline.
            } else if (o.ruleHas("Psalmi\\s*(minores)*\\s*Dominica") || o.communeRuleHas("Psalmi\\s*(minores)*\\s*Dominica")) &&
                (!is1960(rite) || o.rank >= 6) {
                ant = list[0].ant; antEng = list[0].antEng; psalms = list[0].psalms ?? []
            }
            if let a = antSec(o.proper, "Ant Completorium") { ant = a.lat; antEng = a.eng }
        }
        // Seasonal antiphons (temporal office, or Paschaltide).
        if o.temporal || o.dayName.hasPrefix("Pasc") {
            var ind: Int
            switch hour { case "prima": ind = 0; case "tertia": ind = 1; case "sexta": ind = 2; case "nona": ind = 4; default: ind = -1 }
            var name = tempora("Psalmi minor", o, dow, rite)
            if name == "Adv" {
                name = o.dayName
                let day = o.date.day
                if (17...23).contains(day) && dow > 0 { name = "Adv4\(dow + 1)" }
            }
            if name == "Pasch" && (!o.dayName.hasPrefix("Pasc7") || hour == "completorium") { ind = 0 }
            if !name.isEmpty && ind >= 0, let l = psalmiRaw("Minor \(name)"), ind < l.count {
                if !(l[ind].ant.isNullOrBlank) { ant = l[ind].ant; antEng = l[ind].antEng }
            }
        }
        var feastflag = 0
        if hour != "completorium" {
            var w: Hour.Part? = antSec(o.proper, "Ant \(hora)")
            if w == nil && !o.ruleHas("Psalmi\\s*(?:minores)*\\s*ex Psalterio") && !(is1955or1960(rite) && o.rank < 6 && dow > 0) {
                w = antHoras(o, hour, rite)
            }
            if let w { ant = w.lat; antEng = w.eng }
            if (o.ruleHas("Psalmi\\s*(?:minores)*\\s*Dominica") || o.communeRuleHas("Psalmi\\s*(?:minores)*\\s*Dominica")) &&
                !o.ruleHas("Psalmi\\s*(?:minores)*\\s*ex Psalterio") && !(is1955or1960(rite) && o.rank < 6 && dow > 0) {
                feastflag = 1
            }
            if is1955or1960(rite) && o.rank < 6 { feastflag = 0 }
            if o.isSunday && !o.dayName.has("Nat|Pasc6") { feastflag = 0 }
        }
        if o.ruleHas("Minores sine Antiphona") { ant = nil; antEng = nil }
        if hour == "prima" {
            psalms = (laudes != 2 || is1960(rite)) ? psalms.filter { !$0.hasPrefix("[") } : psalms.map { $0.trimChars("[]") }
            if feastflag != 0 && !psalms.isEmpty { psalms[0] = "53" }
            if laudes == 2 && o.isSunday && !is1960(rite) && !psalms.isEmpty {
                psalms[0] = "99"; psalms.insert("92", at: 0)
            }
        }
        if hour == "prima" && dow == 0 && !o.ruleHas("Non dicitur Quicumque") &&
            ((is1955or1960(rite) && o.dayName == "Pent01") ||
                (!is1955or1960(rite) && o.dayName.has("^(Epi|Pent)") &&
                    (o.dayName.has("^(Adv|Pent01|Pasc1)") || suffragiumApplies(o, nil)))) {
            psalms.append("234")
        }
        let antKey = hour == "completorium" ? "completorium.antiphon" : "ant_\(hour)"
        out[antKey] = antPart(ant, antEng, antKey, "Antiphon")
        let maxSlots = hour == "prima" ? 4 : 3
        for k in 1...maxSlots {
            let vk = "\(hour).psalm\(k)"
            guard k - 1 < psalms.count else { drop.insert(vk); continue }
            out[vk] = psalmPart(vk, [psalms[k - 1]], nil, nil)
        }
        if psalms.count > maxSlots {
            let vk = "\(hour).psalm\(maxSlots)"
            out[vk] = psalmPart(vk, Array(psalms.dropFirst(maxSlots - 1)), nil, nil)
        }
    }

    /// DO getanthoras: the little-hours antiphons taken from the Lauds
    /// antiphons on feasts with "Antiphonas horas".
    private func antHoras(_ o: Office, _ hour: String, _ rite: MissalRite) -> Hour.Part? {
        if !(o.ruleHas("Antiphonas horas") || o.communeRuleHas("Antiphonas horas")) { return nil }
        if is1960(rite) && o.rank < 6 { return nil }
        if rite == .rite1955 && o.rank < 6 && o.date.dow > 0 { return nil }
        var w = antList(o.proper, "Ant Laudes")
        if w == nil && o.communeType == "ex" { w = antList(o.commune, "Ant Laudes") }
        guard let list = w, list.count > 3 else { return nil }
        let ind: Int
        switch hour { case "prima": ind = 0; case "tertia": ind = 1; case "sexta": ind = 2; default: ind = 4 }
        guard ind < list.count else { return nil }
        var p = Hour.Part(type: "antiphon"); p.lat = list[ind].ant; p.eng = list[ind].antEng
        return p
    }

    // MARK: Matins psalms

    private func psalmiMatutinum(_ o: Office, _ dow: Int, _ laudes: Int, _ rite: MissalRite,
                                 _ out: inout [String: Hour.Part], _ drop: inout Set<String>) -> (Int, Int) {
        guard var lines = psalmiLines("Day\(dow)") else { return (1, 3) }
        if dow == 0 && o.dayName.hasPrefix("Adv"), let l = psalmiLines("Adv 0 Ant Matutinum") { lines = l }
        if laudes == 2 && dow == 3 && o.key != "12-24", let l = psalmiLines("Day31") { lines = l }
        let name = tempora("Psalmi Matutinum", o, dow, rite)
        func setVers(_ idx: Int, _ sec: String) {
            guard let v = vrLines(psalt(sec)) else { return }
            if idx + 1 < lines.count {
                lines[idx] = v.0
                lines[idx + 1] = v.1
            }
        }
        if !name.isEmpty && (o.temporal || name == "Nat" || name == "Epi") {
            if dow == 0 {
                for i in 1...3 { setVers((i - 1) * 5 + 3, "\(name) \(i) Versum") }
                if is1960(rite) && lines.count > 14 { lines[13] = lines[3]; lines[14] = lines[4] }
            } else {
                var i = dow
                if i > 3 { i -= 3 }
                setVers(13, "\(name) \(i) Versum")
            }
        }
        // Proper antiphons (getantmatutinum).
        var w = antList(o.proper, "Ant Matutinum")
        if w == nil && o.communeType == "ex" { w = antList(o.commune, "Ant Matutinum") }
        let proper = w != nil
        if let w {
            if w.count < 15 {
                // Intersperse the nocturn versicles (DO getantmatutinum): a
                // missing versicle adds nothing, so a 5-line proper keeps its
                // own ℣/℟ at lines 3-4.
                var res: [AntLine] = []
                var rest = w
                for n in 1...3 {
                    let ppN = min(3, rest.count)
                    for _ in 0..<ppN { res.append(rest.removeFirst()) }
                    if let v = vrLines(proprium(o, "Nocturn \(n) Versum", true)) { res.append(v.0); res.append(v.1) }
                }
                lines = res
            } else { lines = w }
        }
        if o.dayName.has("^Pasc[1-6]") && !o.ruleHas("C9|C12") {
            lines = antMatutinumPaschal(lines, o, dow, rite, proper)
        }
        let type1960 = type1960(o, rite)
        let nine = o.ruleHas("9 lectio") && type1960 == 0 && o.rank >= 2
        let nocturns: Int
        let lessons: Int
        let psalmIdx: [Int]
        if nine {
            if !hasSection(o.proper, "Ant Matutinum") {
                if (name == "Pasch" || name == "Asc") && o.rank < 5 && !o.rankHas("(?:in|post).*octava.*Ascensio") {
                    let dname = o.isSunday ? "Dominica" : "Feria"
                    if let spec = psalmiLines("Pasch Ant \(dname)") {
                        for i in [3, 4, 8, 9, 13, 14] where i < spec.count && i < lines.count { lines[i] = spec[i] }
                    }
                } else if o.temporal && ["Adv", "Quad", "Pasch"].contains(name) {
                    for i in 1...3 { setVers((i - 1) * 5 + 3, "\(name) \(i) Versum") }
                }
            }
            nocturns = 3; lessons = 9
            psalmIdx = [0, 1, 2, 5, 6, 7, 10, 11, 12]
            for n in 1...3 {
                let vi = (n - 1) * 5 + 3
                out["nocturn_\(n)_versum"] = vrParts(vi < lines.count ? lines[vi] : nil, vi + 1 < lines.count ? lines[vi + 1] : nil, "nocturn_\(n)_versum")
            }
        } else {
            nocturns = 1; lessons = 3
            let vn = dow2i(dow)
            var v: (AntLine, AntLine)? = nil
            if o.dayName.has("^Pasc[1-6]") && !o.ruleHas("C9|C12") {
                v = (is1960(rite) && name == "Asc") ? vrLines(temporalPropers["pasc5-4"]?["nocturn_\(vn)_versum"]) : vrLines(psalt("Pasch \(vn) Versum"))
            }
            psalmIdx = lines.count > 9 ? [0, 1, 2, 5, 6, 7, 10, 11, 12] : [0, 1, 2]
            if v == nil, lines.count > 14 { v = (lines[13], lines[14]) }
            if o.date.month == 12 && o.date.day == 24, let x = vrLines(psalt("Nat24 Versum")) { v = x }
            if o.dayName.has("^Pasc[07]"), lines.count > 4 { v = (lines[3], lines[4]) }
            out["nocturn_1_versum"] = vrParts(v?.0, v?.1, "nocturn_1_versum")
        }
        // "Ant Matutinum N special": one antiphon of the list replaced by the
        // proper's own (the Annunciation's ninth).
        if let m = o.rule.rmatch("Ant Matutinum (\\d+) special", ci: true) {
            var idx = Int(m[1]) ?? 0
            if idx == 12 && o.dayName.hasPrefix("Pasc") { idx = 10 }
            let wa = o.proper.sec("Ant Matutinum \(m[1])")
            if let wa, idx < lines.count {
                let old = lines[idx]
                lines[idx] = AntLine(ant: self.lines(wa).first ?? old.ant, antEng: engLines(wa).first ?? old.antEng, psalms: old.psalms)
            }
        }
        for (slot, li) in psalmIdx.enumerated() {
            let vk = "matutinum.psalm\(slot + 2)"
            guard li < lines.count, let ps = lines[li].psalms, !ps.isEmpty else { drop.insert(vk); continue }
            out[vk] = psalmPart(vk, ps, lines[li].ant, lines[li].antEng)
        }
        if psalmIdx.count == 3 { for k in 5...10 { drop.insert("matutinum.psalm\(k)") } }
        drop.formUnion(["ant_1", "ant_2", "ant_3"])
        return (nocturns, lessons)
    }

    private func antMatutinumPaschal(_ psalmi: [AntLine], _ o: Office, _ dow: Int, _ rite: MissalRite, _ proper: Bool) -> [AntLine] {
        var res = psalmi
        if dow != 0 || (o.dayName.hasPrefix("Pasc6") && is1960(rite)) {
            if !proper || o.isC10 {
                for i in res.indices where res[i].psalms != nil { res[i] = AntLine(ant: nil, antEng: nil, psalms: res[i].psalms) }
                if !res.isEmpty { res[0] = AntLine(ant: alleluiaAnt, antEng: alleluiaAntEng, psalms: res[0].psalms) }
                if dow != 0 && o.ruleHas("9 lectio") && (!is1960(rite) || o.rank > 3) && o.rank >= 2 {
                    if res.count > 5 { res[5] = AntLine(ant: alleluiaAnt, antEng: alleluiaAntEng, psalms: res[5].psalms) }
                    if res.count > 10 { res[10] = AntLine(ant: alleluiaAnt, antEng: alleluiaAntEng, psalms: res[10].psalms) }
                }
            } else if o.sanctoral {
                for i in 0...3 {
                    for j in [1, 2] {
                        let idx = i * 5 + j
                        if idx < res.count && res[idx].psalms != nil { res[idx] = AntLine(ant: nil, antEng: nil, psalms: res[idx].psalms) }
                    }
                }
            }
        } else if o.dayName.has("^Pasc[1-5]") && o.isSunday {
            if let a = psalmiLines("Pasch0") {
                for i in res.indices where i < a.count { res[i] = AntLine(ant: a[i].ant, antEng: a[i].antEng, psalms: res[i].psalms) }
            }
            if is1960(rite) { for i in 1..<max(res.count, 1) where i < res.count && res[i].psalms != nil { res[i] = AntLine(ant: nil, antEng: nil, psalms: res[i].psalms) } }
        }
        return res
    }

    /// DO gettype1960: 0 default, 1 ferial, 2 Sunday, 3 sanctoral, 4 octave II.
    private func type1960(_ o: Office, _ rite: MissalRite) -> Int {
        var type = 0
        if is1960(rite) && !o.ruleHas("C9|Defunctorum") {
            if o.rankHas("post Nativitatem") { type = 4 }
            else if o.rank < 2 || o.rankHas("(feria|vigilia|die)") { type = 1 }
            else if o.rankHas("dominica.*?semiduplex") || o.key == "pasc1-0" { type = 2 }
            else if o.rank < 5 { type = 3 }
            else { type = 0 }
        }
        if o.ruleHas("9 lectiones 1960|12 lectiones") { type = 0 }
        return type
    }

    /// DO tedeum_required.
    private func teDeumRequired(_ o: Office, _ dow: Int, _ lessons: Int, _ rite: MissalRite) -> Bool {
        let nine = o.ruleHas("9 lectiones")
        let last = (lessons == 9 && nine) || (lessons == 3 && (!nine || o.duplex == 1 || (is1955or1960(rite) && type1960(o, rite) != 0)))
        if !last { return false }
        if o.ruleHas("no Te Deum") && !(o.key == "12-28" && dow == 0) { return false }
        if o.communeKey == "C9" { return false }
        if o.temporal && o.dayName.has("^(Adv|Quad)") { return false }
        return (dow == 0 && !o.rankHas("Vigilia")) ||
            (o.sanctoral && !o.rankHas("Vigilia")) ||
            o.ruleHas("Feria Te Deum") ||
            o.dayName.has("^(Pasc|Nat)") || o.isC10 ||
            (o.temporal && o.rank > 5 && dow != 0) ||
            (!is1955or1960(rite) && (o.key.matchesWhole("pent01-[56]") || o.key.matchesWhole("pent02-[1-4]"))) ||
            (rite == .pre1955 && (o.key == "pent02-6" || o.key.matchesWhole("pent03-[1-5]")))
    }

    // MARK: capitula, hymns, versicles

    private func capitulumMajor(_ hour: String, _ o: Office, _ dow: Int, _ vespera: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        var name = "Capitulum Laudes"
        if o.key == "12-25" && vespera == 1 { name = "Capitulum Vespera 1" }
        if o.communeKey == "C12" && hour == "vesperae" { name = "Capitulum Vespera" }
        let vk = hour == "laudes" ? "capitulum_laudes" : "vesperae.capitulum"
        var capit = proprium(o, name, true)
        if capit == nil && name != "Capitulum Laudes" { capit = proprium(o, "Capitulum Laudes", true) }
        if capit == nil {
            var t = tempora("Capitulum major", o, dow, rite)
            let h = hour == "laudes" ? "Laudes" : "Vespera"
            if (t == "Asc" || t == "Pent") && psalt("\(t) \(h)") == nil { t = "Pasch" }
            if (t == "Nat" || t == "Epi") && psalt("\(t) \(h)") == nil { t = dow == 0 ? "Dominica" : "Feria" }
            capit = (hour == "vesperae" && dow == 6 && t == "Feria") ? (psalt("Feria Vespera (feria 7)") ?? psalt("\(t) \(h)"))
                : (psalt("\(t) \(h)") ?? psalt("Feria \(h)"))
        }
        if let c = capit { out[vk] = rekey(c.withType("capitulum"), vk, "Capitulum") }
    }

    private func capitulumMinor(_ hour: String, _ o: Office, _ dow: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        guard let hora = hourTitles[hour] else { return }
        var t = tempora("Capitulum minor", o, dow, rite)
        if (t == "Asc" || t == "Pent") && psalt("\(t) \(hora)") == nil { t = "Pasch" }
        if (t == "Nat" || t == "Epi") && psalt("\(t) \(hora)") == nil { t = (dow == 0 || (o.rankHas("Duplex") && !o.rankHas("Dominica|Vigilia"))) ? "Dominica" : "Feria" }
        let vk = hour == "tertia" ? "tertia.capitulum" : "capitulum_\(hour)"
        var capit: Hour.Part? = psalt("\(t) \(hora)") ?? psalt("Feria \(hora)")
        let secName = (hour == "tertia" && o.communeKey != "C12") ? "Capitulum Laudes" : "Capitulum \(hora)"
        if let p = proprium(o, secName, true) { capit = p }
        if let c = capit { out[vk] = rekey(c.withType("capitulum"), vk, "Capitulum") }
        let rvk = "responsory_breve_\(hour)"
        let vvk = "versum_\(hour)"
        var resp: Hour.Part? = psalt("Responsory breve \(t) \(hora)") ?? psalt("Responsory breve Feria \(hora)")
        var vers: Hour.Part? = psalt("Versum \(t) \(hora)") ?? psalt("Versum Feria \(hora)")
        if let wr = proprium(o, "Responsory Breve \(hora)", true) { resp = wr }
        if let wv = proprium(o, "Versum \(hora)", true) { vers = wv }
        if let r = resp { out[rvk] = rekey(r.withType("responsory"), rvk, "Responsorium Breve") }
        if let v = vers { var p = vrFrom(v, vvk); p.label = "Versiculus"; out[vvk] = p }
    }

    private func hymnusMinor(_ hour: String, _ o: Office, _ out: inout [String: Hour.Part]) {
        guard let hora = hourTitles[hour] else { return }
        var name = "Hymnus \(hora)"
        if hour == "tertia" && o.dayName.hasPrefix("Pasc7") { name = "Hymnus Pasc7 Tertia" }
        let vk = "\(hour).hymn"
        if let h = psalt(name) ?? psalt("Hymnus \(hora)") { out[vk] = rekey(h, vk) }
    }

    private func checkmtv(_ o: Office, _ rite: MissalRite) -> String {
        ((is1955or1960(rite) || o.ruleHas(";mtv")) && o.ruleHas("C[45]")) ? "1" : ""
    }

    private func hymnusMajor(_ hour: String, _ o: Office, _ dow: Int, _ vespera: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        let hora = hour == "laudes" ? "Laudes" : "Vespera"
        let vk = hour == "laudes" ? "hymnus_laudes" : "hymnus_vespera"
        var name = "Hymnus"
        if hour == "vesperae" { name += checkmtv(o, rite) }
        if name != "Hymnus" && o.proper.sec("\(name) \(hora)") == nil && o.proper.sec("Hymnus \(hora)") != nil { name = "Hymnus" }
        var hymn: Hour.Part? = nil
        // DO hymnshift: Vespers hymn at Matins, Matins hymn at Lauds, Lauds hymn at Vespers;
        // hymnshiftmerge: Lauds takes the Matins hymn ending with the Lauds hymn.
        if o.hymnShift == 2 && proprium(o, "\(name) \(hora)", true) != nil {
            hymn = proprium(o, hour == "laudes" ? "\(name) Matutinum" : "\(name) Laudes", true)
        } else if o.hymnShift == 3 && hour == "laudes" {
            if let hl = proprium(o, "\(name) Laudes", true), let hm = proprium(o, "\(name) Matutinum", true) {
                let stanzas = (hm.lat ?? "").components(separatedBy: "\n\n")
                var n = hm
                n.lat = (Array(stanzas.dropLast()) + [(hl.lat ?? "").dropPrefix("v. ")]).joined(separator: "\n\n")
                let e = [hm.eng, hl.eng].compactMap { $0 }.joined(separator: "\n\n")
                n.eng = e.isBlank ? nil : e
                hymn = n
            }
        }
        if hymn == nil && hour == "vesperae" && vespera == 3 { hymn = proprium(o, "\(name) Vespera 3", true) ?? proprium(o, "Hymnus Vespera 3", true) }
        if hymn == nil { hymn = proprium(o, "\(name) \(hora)", true) }
        if hymn == nil && name != "Hymnus" { hymn = proprium(o, "Hymnus \(hora)", true) }
        if hymn == nil {
            let t = tempora("Hymnus major", o, dow, rite)
            var key = "Hymnus \(t) \(hora)"
            if t == "Day0" && hour == "laudes" &&
                (o.dayName.has("^Epi[2-6]") || o.dayName.hasPrefix("Quadp") ||
                    o.rankHas("Novembris|Octobris") || ([10, 11].contains(o.date.month) && o.temporal && dow == 0)) {
                key += " hiemalis"
            }
            if (t == "Asc" || t == "Pent" || t == "Nat" || t == "Epi") && psalt(key) == nil {
                key = "Hymnus " + ((t == "Asc" || t == "Pent") ? "Pasch" : "Day\(dow)") + " \(hora)"
            }
            hymn = psalt(key) ?? psalt("Hymnus Day\(dow) \(hora)")
        }
        if let h = hymn { out[vk] = rekey(h.withType("hymn"), vk, "Hymn") }
    }

    private func versumMajor(_ hour: String, _ o: Office, _ dow: Int, _ vespera: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        let ind = hour == "laudes" ? 2 : vespera
        let vk = hour == "laudes" ? "versum_1" : "versum_2"
        var w = proprium(o, "Versum \(ind)", true)
        if w == nil && ind > 1 { w = proprium(o, "Versum \(4 - ind)", true) }
        if w == nil {
            var t = tempora("getfrompsalterium major", o, dow, rite)
            if (t == "Asc" || t == "Pent") && psalt("\(t) Versum \(ind)") == nil { t = "Pasch" }
            if t == "Nat" || t == "Epi" { t = dow == 0 ? "Dominica" : "Feria" }
            w = (hour == "vesperae" && dow == 6 && t == "Feria") ? psalt("Feria Versum 3 (feria 7)") : nil
            if w == nil { w = psalt("\(t) Versum \(ind)") ?? psalt("\(t) Versum 1") ?? psalt("\(t) Versum 3") ?? psalt("\(t) Versum 2") }
        }
        if let w { var p = vrFrom(w, vk); p.label = "Versicle"; out[vk] = p }
    }

    private func canticleAntiphon(_ hour: String, _ o: Office, _ dow: Int, _ vespera: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part], _ today: LDate) {
        let ind = hour == "laudes" ? 2 : vespera
        let vk = hour == "laudes" ? "ant_laudes" : "ant_vespera"
        let label = hour == "laudes" ? "Antiphon ad Benedictus" : "Antiphon ad Magnificat"
        var w = proprium(o, "Ant \(ind)", true)
        if w == nil && ind > 1 { w = proprium(o, "Ant \(4 - ind)", true) }
        // The O antiphons (DO ant123_special): Vespers Dec 17-23, and the
        // Lauds of Dec 21 and 23, when the office is of the season.
        if o.temporal && today.month == 12 && (17...23).contains(today.day) {
            if hour == "laudes" && (today.day == 21 || today.day == 23) { if let p = psalt("Adv Ant \(today.day)L") { w = p } }
            else if hour == "vesperae" { if let p = psalt("Adv Ant \(today.day)") { w = p } }
        }
        if w == nil {
            var t = tempora("getfrompsalterium major", o, dow, rite)
            if t != "Dominica" { t = dow == 0 ? "Dominica" : "Feria" }
            if t == "Feria" {
                let fk = (hour == "vesperae" && dow == 6) ? "Feria Ant \(ind) (feria 7)" : "Feria\(dow + 1) Ant \(ind)"
                w = psalt(fk) ?? psalt("Feria\(dow + 1) Ant \(ind)") ?? psalt("Feria\(dow + 1) Ant \(4 - ind)")
            }
        }
        if let w, lines(w).count == 1 { out[vk] = antPart(lines(w)[0], engLines(w).first, vk, label) }
    }

    private func primaPieces(_ o: Office, _ dow: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        // DO capitulum_prima: "Regi sæculórum" on every day under the 1960
        // rubrics; the ferial "Pacem et veritátem" only in the older books.
        let feriaKey = dow > 0 && !is1960(rite) && o.rankHas("Feria|Vigilia") && !o.rankHas("Vigilia Epi") &&
            !o.isC10 && (o.rank < 3 || o.dayName.hasPrefix("Quad6") || o.key == "quadp3-3") && !o.dayName.hasPrefix("Pasc")
        if let cap = psalt(feriaKey ? "Prima Feria" : "Prima Dominica") { out["prima.capitulum"] = rekey(cap, "prima.capitulum", "Capitulum") }
        // Responsory: the ℣ changes with the season.
        var tr = tempora("Prima responsory", o, dow, rite)
        if let m = o.rule.rmatch("Doxology=(Nat|Epi|Pasch|Asc|Corp|Heart)", ci: true) { tr = m[1] }
        if !is1960(rite) && o.date.month == 8 && (16...22).contains(o.date.day) { tr = "Nat" }
        if is1960(rite) && o.date.month == 12 && (9...15).contains(o.date.day) && o.date.day != 12 { tr = "Adv" }
        if is1960(rite) && (tr == "Corp" || tr == "Heart") { tr = "" }
        if let base = psalt("Prima Responsory") {
            var lat = base.lat ?? ""
            var eng = base.eng
            let variant = tr.isEmpty ? nil : psalt("Prima Responsory \(tr)")
            if let variant {
                let vl = NSRegularExpression.escapedTemplate(for: "℣. " + (variant.lat ?? ""))
                lat = lat.rreplace("℣\\. [^\n]*", vl)
                if let e = eng, let ve = variant.eng { eng = e.rreplace("℣\\. [^\n]*", NSRegularExpression.escapedTemplate(for: "℣. " + ve)) }
            }
            var p = base
            p.lat = lat; p.eng = eng; p.variationKey = "prima.responsory"; p.label = "Responsorium Breve"
            out["prima.responsory"] = p
        }
        if let v = psalt("Prima Versum") { var p = vrFrom(v, "versum_prima"); p.label = "Versiculus"; out["versum_prima"] = p }
        if let h = psalt("Prima Hymnus Prima") { out["prima.hymn"] = rekey(h, "prima.hymn") }
        // Lectio brevis: seasonal / per annum; the proper's own only in the older books.
        var brevis: Hour.Part? = psalt("Prima " + tempora("Lectio brevis Prima", o, dow, rite))
        if !is1955or1960(rite), let p = proprium(o, "Lectio Prima", true) { brevis = p }
        if let b = brevis {
            var p = b.withType("reading"); p.label = "Lectio brevis"; p.variationKey = "lectio_prima"
            out["lectio_prima"] = p
        }
    }

    private func complinePieces(_ o: Office, _ dow: Int, _ vespera: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        if let h = psalt("Hymnus Completorium") { out["completorium.hymn"] = rekey(h, "completorium.hymn") }
        if let c = psalt("Completorium") { out["completorium.capitulum"] = rekey(c, "completorium.capitulum", "Capitulum") }
        if let r = psalt("Responsory Completorium") { out["completorium.responsory"] = rekey(r, "completorium.responsory", "Responsorium Breve") }
        let a4: Hour.Part?
        if o.ruleHas("Minores sine Antiphona") && o.dayName.hasPrefix("Quad6") {
            var p = Hour.Part(type: "antiphon"); p.lat = ""; p.eng = ""; a4 = p
        } else {
            a4 = proprium(o, "Ant 4\(vespera)", false) ?? proprium(o, "Ant 4", false) ?? psalt("Ant 4")
        }
        if let a = a4 {
            // Antiphon only: the assembler merges it onto the canticle. A
            // second line (Easter week's "Hæc dies") stands in place of the
            // capitulum, hymn and versicle (DO prints it after the canticle).
            let al = lines(a); let ae = engLines(a)
            var c = Hour.Part(type: "canticle"); c.variationKey = "completorium.canticle"
            c.antiphonLat = al.first ?? a.lat; c.antiphonEng = ae.first ?? a.eng
            out["completorium.canticle"] = c
            if al.count > 1 {
                var p = Hour.Part(type: "antiphon"); p.label = "In loco Capituli"; p.lat = al[1].dropPrefix("Ant. ")
                p.eng = ae.count > 1 ? ae[1].dropPrefix("Ant. ") : nil; p.variationKey = "completorium.capitulum"
                out["completorium.capitulum"] = p
            }
        }
    }

    private func invitatorium(_ o: Office, _ dow: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        let name = tempora("Invitatorium", o, dow, rite)
        var ant: Hour.Part? = nil
        if !name.isEmpty { ant = psalt("Invit \(name)") }
        if ant == nil {
            let names = ["Dominica", "Feria II", "Feria III", "Feria IV", "Feria V", "Feria VI", "Sabbato"]
            var n = names[dow]
            let m = o.date.month
            if dow == 0 && (m < 4 || [10, 11].contains(m)) { n = "Invit 1" }
            ant = psalt("Invit \(n)") ?? psalt("Invit Dominica")
        }
        if let p = proprium(o, "Invit", true) { ant = p }
        if let a = ant { out["invit"] = antPart(a.lat, a.eng, "invit", "Invitatory Antiphon") }
    }

    private func hymnusMatutinum(_ o: Office, _ dow: Int, _ rite: MissalRite, _ out: inout [String: Hour.Part]) {
        var name = "Hymnus"
        if o.proper.sec("Hymnus Matutinum") == nil { name += checkmtv(o, rite) }
        var h = proprium(o, "\(name) Matutinum", true)
        if h == nil && name != "Hymnus" { h = proprium(o, "Hymnus Matutinum", true) }
        // DO hymnshift / hymnmerge: a I Vespers hymn omitted by concurrence
        // moves to Matins; if II Vespers went too, the two hymns merge.
        if h != nil && (o.hymnShift == 2 || o.hymnShift == 3) {
            if let hv = proprium(o, "\(name) Vespera", true) { h = hv }
        } else if let hm = h, o.hymnShift == 1 {
            if let hv = proprium(o, "\(name) Vespera", true) {
                let mat = (hm.lat ?? "").dropPrefix("v. ")
                let stanzas = (hv.lat ?? "").components(separatedBy: "\n\n")
                let merged = (Array(stanzas.dropLast()) + [mat]).joined(separator: "\n\n")
                var n = hv
                n.lat = merged
                let e = [hv.eng, hm.eng].compactMap { $0 }.joined(separator: "\n\n")
                n.eng = e.isBlank ? nil : e
                h = n
            }
        }
        if h == nil {
            let t = tempora("Hymnus matutinum", o, dow, rite)
            var key = (!t.isEmpty && t != "Nat" && t != "Epi") ? "Hymnus \(t)" : "Day\(dow) Hymnus"
            let m = o.date.month
            if key == "Day0 Hymnus" && (m < 4 || [10, 11].contains(m)) { key = "Day0 Hymnus1" }
            h = psalt(key) ?? psalt("Day\(dow) Hymnus")
        }
        if let h { out["hymnus_matutinum"] = rekey(h.withType("hymn"), "hymnus_matutinum", "Hymn") }
    }

    // MARK: preces

    private func precesFeriales(_ o: Office, _ dow: Int, _ hour: String, _ rite: MissalRite) -> Bool {
        if o.communeKey == "C12" || o.ruleHas("Omit.*? Preces") || o.duplex > 2 || o.dayName.has("^Pasc[67]") { return false }
        if !["laudes", "vesperae", "prima", "tertia", "sexta", "nona", "completorium"].contains(hour) { return false }
        if dow == 0 { return false }
        if dow == 6 && hour == "vesperae" { return false }
        let ferial = (o.temporal && (o.ruleHas("Preces") || o.dayName.hasPrefix("Adv") ||
            (o.dayName.hasPrefix("Quad") && !o.dayName.hasPrefix("Quadp")) || emberDay(o, dow))) ||
            (!is1955or1960(rite) && o.rankHas("vigil") && !o.rankHas("Epi|Pasc"))
        if !ferial { return false }
        return !is1955or1960(rite) || dow == 3 || dow == 5 || emberDay(o, dow)
    }

    /// DO preces('Dominicales'): the Sunday preces of Prime and Compline
    /// (the older books), unless a Duplex or an octave is commemorated.
    private func precesDominicales(_ o: Office, _ commem: Office?, _ rite: MissalRite) -> Bool {
        if o.communeKey == "C12" || o.ruleHas("Omit.*? Preces") || o.duplex > 2 || o.dayName.has("^Pasc[67]") { return false }
        if o.rankHas("octav") && !o.rankHas("post octav") { return false }
        func blocks(_ w: Office) -> Bool { w.rank >= 3 || w.rankLine.has("octav", ci: true) }
        if let commem, blocks(commem) { return false }
        for ck in o.commemorations { if blocks(officeFromKey(ck, o.date, rite)) { return false } }
        return true
    }

    /// The preces DO says at Prime, the little hours and Compline (its
    /// Psalterium scripts), when they apply.
    private func precesScript(_ o: Office, _ hourSlug: String, _ feriales: Bool, _ dominicales: Bool, _ dow: Int) -> [Hour.Part]? {
        let key: String
        switch hourSlug {
        case "tertia", "sexta", "nona": guard feriales else { return nil }; key = "Preces Feriales"
        case "completorium": guard feriales || dominicales else { return nil }; key = "Preces Dominicales"
        case "prima":
            if feriales { key = "Preces feriales Prima" } else if dominicales { key = "Preces Dominicales Prima 1" } else { return nil }
        default: return nil
        }
        guard let sec = psalt(key) else { return nil }
        let parts = renderScript(sec, o, hourSlug, dow)
        if parts.isEmpty { return nil }
        var h = Hour.Part(type: "heading"); h.label = feriales ? "Preces Feriales" : "Preces Dominicales"
        return [h] + parts
    }
}
