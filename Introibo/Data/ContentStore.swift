import Foundation
import SwiftUI

// Loads bundled JSON content on first access and keeps it in memory.
// Exposed via @Observable so views can inject a single shared instance
// through @Environment; per-view ContentStore() is also fine since the
// load is cheap and the payload is small.

@Observable
final class ContentStore {
    static let shared = ContentStore()

    private(set) var prayers:        [Prayer]          = []
    private(set) var reference:      [ReferenceEntry]  = []
    private(set) var saints:         [Saint]           = []
    private(set) var courses:        [Course]          = []
    private(set) var missal:         [MissalSection]   = []
    private(set) var mysterySets:    [MysterySetData]  = []
    private(set) var rosaryPrayers:  [RosaryPrayer]    = []
    private(set) var stations:       [Station]             = []
    private(set) var hours:          [Hour]                = []
    private(set) var marianAntiphons:[MarianAntiphonData]  = []
    private(set) var examen:         [ExamenEntry]         = []
    private(set) var confessionGuides:[ConfessionGuide]    = []
    private(set) var propers:         [MassProper]          = []
    private var canonVariants: [String: [String: [String: String]]] = [:]
    private var officeAssembler = OfficeAssembler(weeklyPsalter: [:], seasonalHymns: [:], temporalPropers: [:], marianAntiphons: [])
    private var missalTempora:   [String: MissalProperEntry] = [:]
    private var missalSanctoral: [String: MissalProperEntry] = [:]
    private var sanctoralPropers: [String: [String: Hour.Part]] = [:]
    private var ordoData:        [String: OrdoEntry] = [:]
    private var ordoData1955:    [String: OrdoEntry] = [:]
    private var ordoDataPre1955: [String: OrdoEntry] = [:]

    init() {
        prayers           = load("prayers",            as: [Prayer].self)              ?? []
        reference         = load("reference",          as: [ReferenceEntry].self)      ?? []
        saints            = load("saints",             as: [Saint].self)               ?? []
        courses           = load("courses",            as: [Course].self)              ?? []
        missal            = load("missal",             as: [MissalSection].self)       ?? []
        mysterySets       = load("mysteries",          as: [MysterySetData].self)      ?? []
        rosaryPrayers     = load("rosary_prayers",     as: [RosaryPrayer].self)        ?? []
        stations          = load("stations",           as: [Station].self)             ?? []
        hours             = load("hours",              as: [Hour].self)                ?? []
        marianAntiphons   = load("marian_antiphons",   as: [MarianAntiphonData].self)  ?? []
        examen            = load("confession_examen", as: [ExamenEntry].self)          ?? []
        confessionGuides  = load("confession_guides", as: [ConfessionGuide].self)      ?? []
        propers           = load("propers",            as: [MassProper].self)          ?? []
        canonVariants     = load("canon_variants",     as: [String: [String: [String: String]]].self) ?? [:]
        missalTempora     = load("missal_tempora",    as: [String: MissalProperEntry].self) ?? [:]
        missalSanctoral   = load("missal_sanctoral",  as: [String: MissalProperEntry].self) ?? [:]
        sanctoralPropers  = load("sanctoral_propers", as: [String: [String: Hour.Part]].self) ?? [:]
        ordoData          = load("ordo",              as: [String: OrdoEntry].self) ?? [:]
        ordoData1955      = load("ordo_1955",         as: [String: OrdoEntry].self) ?? [:]
        ordoDataPre1955   = load("ordo_pre1955",      as: [String: OrdoEntry].self) ?? [:]

        let psalter  = load("psalter_weekly",    as: [String: [String: Hour.Part]].self) ?? [:]
        let hymns    = load("hymns_seasonal",   as: [String: [String: Hour.Part]].self) ?? [:]
        let temporal = load("temporal_propers",  as: [String: [String: Hour.Part]].self) ?? [:]
        officeAssembler = OfficeAssembler(
            weeklyPsalter: psalter,
            seasonalHymns: hymns,
            temporalPropers: temporal,
            marianAntiphons: marianAntiphons
        )
        buildAllPropers()
    }

    func proper(slug: String) -> MassProper? {
        propers.first { $0.slug == slug }
    }

    func hour(slug: String) -> Hour? {
        hours.first { $0.slug == slug }
    }

    func hourForToday(slug: String) -> Hour? {
        guard let template = hour(slug: slug) else { return nil }
        let ctx = LiturgicalContext.current()
        var assembled = officeAssembler.assemble(template: template, context: ctx)

        // Apply proper collect from the ordo winner (temporal or sanctoral)
        let riteRaw = UserDefaults.standard.string(forKey: SettingsKey.rite) ?? MissalRite.rite1962.rawValue
        let rite = MissalRite(rawValue: riteRaw) ?? .rite1962
        if let ordo = ordoForDate(ctx.date, rite: rite) {
            if ordo.winner == "sanctoral",
               let saint = sanctoralPropers[ordo.winnerKey] {
                assembled = applyProperOverrides(assembled, overrides: saint)
            } else if let temporalKey = ordo.temporal,
                      let tempOverrides = officeAssembler.temporalPropers[temporalKey] {
                assembled = applyProperOverrides(assembled, overrides: tempOverrides)
            }
        }

        return assembled
    }

    private func applyProperOverrides(_ hour: Hour, overrides: [String: Hour.Part]) -> Hour {
        let updatedParts = hour.parts.map { part -> Hour.Part in
            guard let key = part.variationKey else {
                if part.type == "collect", let collect = overrides["collect"] {
                    return collect
                }
                return part
            }
            if let override = overrides[key] { return override }
            if part.type == "collect", let collect = overrides["collect"] {
                return collect
            }
            return part
        }
        return Hour(
            slug: hour.slug, name: hour.name, eng: hour.eng,
            time: hour.time, hour: hour.hour, minute: hour.minute,
            glyph: hour.glyph, order: hour.order, intro: hour.intro,
            parts: updatedParts
        )
    }

    func mysterySet(slug: String) -> MysterySetData? {
        mysterySets.first { $0.slug == slug }
    }

    // MARK: - Ordo & Propers (DivinumOfficium)

    func ordoForDate(_ date: Date, rite: MissalRite = .rite1962) -> OrdoEntry? {
        let cal = Calendar.liturgical
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let key = String(format: "%04d-%02d-%02d", y, m, d)
        switch rite {
        case .rite1962: return ordoData[key]
        case .rite1955: return ordoData1955[key]
        case .pre1955:  return ordoDataPre1955[key]
        }
    }

    func properForToday(rite: MissalRite = .rite1962) -> MassProper? {
        let entry = ordoForDate(Date(), rite: rite)
        return properFromOrdo(entry, rite: rite)
    }

    func properForDate(_ date: Date, rite: MissalRite = .rite1962) -> MassProper? {
        let entry = ordoForDate(date, rite: rite)
        return properFromOrdo(entry, rite: rite)
    }

    private func properFromOrdo(_ entry: OrdoEntry?, rite: MissalRite = .rite1962) -> MassProper? {
        guard let entry = entry else { return nil }
        let key = entry.winnerKey

        if entry.winner == "sanctoral" {
            if let mp = missalSanctoral[key]?.toMassProper(key: key, ordo: entry) { return mp }
            // Christmas: ordo key "12-25" but Mass data is keyed by 12-25m1/m2/m3.
            if key == "12-25", let mp = missalSanctoral["12-25m3"]?.toMassProper(key: "12-25m3", ordo: entry) {
                return mp
            }
            // All Souls: ordo key "11-02" but Mass data is split into 11-02m1/m2/m3.
            if key == "11-02", let mp = missalSanctoral["11-02m1"]?.toMassProper(key: "11-02m1", ordo: entry) {
                return mp
            }
        }
        // Pre-1955 rite: prefer the "r" suffixed variant if present (mirrors DO's
        // Pasc7-6r.txt / Quad6-4r.txt convention for pre-1955-specific formularies).
        if rite == .pre1955 {
            let rKey = "\(key)r"
            if let mp = missalTempora[rKey]?.toMassProper(key: rKey, ordo: entry) { return mp }
            if let mp = missalSanctoral[rKey]?.toMassProper(key: rKey, ordo: entry) { return mp }
        }
        if let mp = missalTempora[key]?.toMassProper(key: key, ordo: entry) { return mp }
        if let mp = missalSanctoral[key]?.toMassProper(key: key, ordo: entry) { return mp }

        // Follow rule.commune redirect (data-driven inheritance for stubs).
        if let mp = resolveCommuneRedirect(forKey: key, ordo: entry) {
            return mp
        }

        // Inheritance: octave days inherit Mass propers from feast day.
        if let parent = inheritedTemporalKey(for: key),
           let mp = missalTempora[parent]?.toMassProper(key: parent, ordo: entry) {
            return mp
        }

        // Fallback to legacy propers.json by slug
        if let mp = propers.first(where: { $0.slug == key }) { return mp }

        // Last resort: ferial days use the preceding Sunday's formulary.
        // Extract the temporal key (e.g. "pent03-4") and replace the day suffix
        // with "-0" to get the Sunday of that week (e.g. "pent03-0").
        if let sundayKey = precedingSundayKey(for: entry) {
            if let mp = missalTempora[sundayKey]?.toMassProper(key: sundayKey, ordo: entry) { return mp }
            // The Sunday itself may be a stub with a commune redirect (e.g.
            // pent27-0 → epi5-0 for "resumed" Sundays after Epiphany).
            // Use a synthetic ordo entry with a non-ferial name to avoid
            // the ferial-suppression heuristic blocking the redirect.
            let sundayOrdo = OrdoEntry(
                temporal: sundayKey, sanctoral: entry.sanctoral,
                winner: "temporal", winnerKey: sundayKey,
                rank: entry.rank, name: missalTempora[sundayKey]?.officium ?? entry.name,
                color: entry.color, season: entry.season,
                commemoration: entry.commemoration
            )
            if let mp = resolveCommuneRedirect(forKey: sundayKey, ordo: sundayOrdo) { return mp }
        }

        return nil
    }

    /// Derives the preceding Sunday's temporal key from an ordo entry.
    /// Given a temporal key like "pent03-4", "adv1-3", "quad2-6", "epi1-2",
    /// replaces the trailing "-D" day suffix with "-0" (the Sunday).
    /// Returns nil if the entry has no temporal key, is already a Sunday, or
    /// does not match the expected format.
    private func precedingSundayKey(for entry: OrdoEntry) -> String? {
        guard let temporal = entry.temporal else { return nil }
        // Match pattern: any prefix followed by "-" and a single digit (1-6)
        guard let dashIdx = temporal.lastIndex(of: "-") else { return nil }
        let daySuffix = temporal[temporal.index(after: dashIdx)...]
        // Must be a single non-zero digit (weekday); "-0" is already Sunday
        guard daySuffix.count == 1,
              let dayNum = Int(daySuffix),
              dayNum >= 1 && dayNum <= 6 else { return nil }
        return String(temporal[...dashIdx]) + "0"
    }

    /// Resolves a `rule.commune` redirect on a stub entry. The redirect may be:
    ///   - "Sancti/01-06"   → missalSanctoral["01-06"]
    ///   - "Tempora/Epi3-0" → missalTempora["epi3-0"] (lowercased)
    ///   - "pentepi3-0"     → tries missalTempora then missalSanctoral
    ///   - "C5", "C2-1" …   → commune key lookup (handled by legacy propers if present)
    /// Returns nil if the entry has no commune redirect, the target is missing,
    /// or the target itself has no Mass propers.
    ///
    /// Suppression: when the ordo's `name` for the date looks ferial (begins with
    /// "Feria " or "Sabbato ") and shares no significant lexical signal with the
    /// redirect target's `officium`, the redirect is treated as inapplicable.
    /// This blocks abolished-octave bleed-through (e.g. 1962 ferias inside the
    /// former Sacred Heart octave should NOT inherit Sacred Heart Mass propers,
    /// while pre-1955 ferias inside the still-extant octave correctly do).
    private func resolveCommuneRedirect(forKey key: String, ordo: OrdoEntry, depth: Int = 0) -> MassProper? {
        guard depth < 4 else { return nil } // safety: prevent cycles
        let stub = missalTempora[key] ?? missalSanctoral[key]
        guard let target = stub?.rule?.commune, !target.isEmpty else { return nil }

        // Split "Section/Key" form
        let parts = target.split(separator: "/", maxSplits: 1).map(String.init)
        let section = parts.count == 2 ? parts[0] : ""
        let bareKey = parts.count == 2 ? parts[1] : target

        // Commune codes (C2, C5b, …) are handled by the legacy propers.json by slug
        // so do nothing here — fall through to caller's legacy lookup.
        if section.isEmpty && bareKey.hasPrefix("C") && bareKey.dropFirst().first?.isNumber == true {
            return nil
        }

        let lowerKey = bareKey.lowercased()

        // Helper: take a resolved target's Mass propers but suppress the inheritance
        // if the ordo says the day is a ferial whose liturgical name has no lexical
        // overlap with the target's officium (i.e., the redirect points at a feast
        // that this rite does not observe on this date).
        func gated(_ targetKey: String, _ entry: MissalProperEntry?) -> MassProper? {
            guard let entry = entry else { return nil }
            if redirectShouldBeSuppressed(ordoName: ordo.name, targetOfficium: entry.officium) {
                return nil
            }
            return entry.toMassProper(key: targetKey, ordo: ordo)
        }

        // Try the section first if specified
        switch section {
        case "Sancti":
            if let mp = gated(bareKey, missalSanctoral[bareKey]) { return mp }
            // Recursively follow if the target is itself a stub.
            if let mp = resolveCommuneRedirect(forKey: bareKey, ordo: ordo, depth: depth + 1) { return mp }
        case "Tempora":
            if let mp = gated(lowerKey, missalTempora[lowerKey]) { return mp }
            if let mp = resolveCommuneRedirect(forKey: lowerKey, ordo: ordo, depth: depth + 1) { return mp }
        default:
            if let mp = gated(lowerKey, missalTempora[lowerKey]) { return mp }
            if let mp = gated(bareKey, missalSanctoral[bareKey]) { return mp }
            if let mp = resolveCommuneRedirect(forKey: lowerKey, ordo: ordo, depth: depth + 1) { return mp }
            if let mp = resolveCommuneRedirect(forKey: bareKey, ordo: ordo, depth: depth + 1) { return mp }
        }
        return nil
    }

    // MARK: Commune-redirect suppression heuristic

    /// Words that are too generic to count as a liturgical "signal" when comparing
    /// the ordo's day-name to a redirect target's officium. These are calendar /
    /// structural words ("Feria", "Hebdomadam", …) that would match across
    /// unrelated formularies and produce false positives.
    private static let redirectSignalStopWords: Set<String> = [
        "feria", "sabbato", "dominica", "die", "dies", "infra", "post",
        "hebdomadam", "hebdomadæ", "hebdomadae", "octava", "octavam",
        "octavæ", "octavae", "festo", "festum", "commemoratio", "in",
        "ad", "ac", "et", "de", "sub", "sancti", "sanctae", "sanctæ"
    ]

    /// Returns true iff the ordo's day-name has a ferial shape AND it shares no
    /// significant lexical signal with the redirect target's officium. In that
    /// case the redirect is deemed inapplicable for this rite-date and should be
    /// suppressed (caller should fall through to the next resolution step,
    /// eventually returning nil if no other Mass is available).
    private func redirectShouldBeSuppressed(ordoName: String, targetOfficium: String?) -> Bool {
        guard let target = targetOfficium, !target.isEmpty else { return false }
        let lowerName = ordoName.lowercased()
        let isFerial = lowerName.hasPrefix("feria ") || lowerName.hasPrefix("sabbato ")
        guard isFerial else { return false }
        let nameTokens = Self.significantTokens(ordoName)
        let targetTokens = Self.significantTokens(target)
        if nameTokens.isEmpty || targetTokens.isEmpty { return false }
        // Latin inflection tolerance: treat tokens as matching when their
        // longest common prefix is ≥5 chars (e.g. "septuagesima" ≈ "septuagesimæ",
        // "epiphaniam" ≈ "epiphaniæ").
        for n in nameTokens {
            for t in targetTokens {
                if Self.commonPrefixLength(n, t) >= 5 { return false }
            }
        }
        return true
    }

    private static func commonPrefixLength(_ a: String, _ b: String) -> Int {
        var ai = a.startIndex
        var bi = b.startIndex
        var n = 0
        while ai < a.endIndex && bi < b.endIndex && a[ai] == b[bi] {
            n += 1
            ai = a.index(after: ai)
            bi = b.index(after: bi)
        }
        return n
    }

    /// Tokenises a Latin liturgical string into "significant" lowercased words:
    /// strips punctuation, drops stop-words (Feria/Hebdomadam/…), drops Roman
    /// numerals, drops short tokens (<4 chars).
    private static func significantTokens(_ s: String) -> [String] {
        let lower = s.lowercased()
        var current = ""
        var out: [String] = []
        for ch in lower {
            if ch.isLetter {
                current.append(ch)
            } else {
                if !current.isEmpty { out.append(current); current = "" }
            }
        }
        if !current.isEmpty { out.append(current) }
        let romanRegex = #"^[ivxlcdm]+$"#
        return out.filter { tok in
            if tok.count < 4 { return false }
            if redirectSignalStopWords.contains(tok) { return false }
            if tok.range(of: romanRegex, options: .regularExpression) != nil { return false }
            return true
        }
    }

    /// Returns the inherited temporal key (e.g., octave days inherit from the feast).
    /// Currently handles the Ascension octave: pasc5-5 through pasc6-* inherit from pasc5-4.
    private func inheritedTemporalKey(for key: String) -> String? {
        // Ascension octave (Pasc5-5 through Pasc6-4)
        let ascensionOctave: Set<String> = [
            "pasc5-5", "pasc5-6", "pasc6-0", "pasc6-1",
            "pasc6-2", "pasc6-3", "pasc6-4"
        ]
        if ascensionOctave.contains(key) { return "pasc5-4" }
        return nil
    }

    // MARK: - All searchable propers (combined old + new)

    private(set) var allPropers: [MassProper] = []

    private func buildAllPropers() {
        var combined: [String: MassProper] = [:]
        // DivinumOfficium data is the source of truth
        for (key, entry) in missalTempora {
            if let mp = entry.toMassProper(key: key) { combined[key] = mp }
        }
        for (key, entry) in missalSanctoral {
            if let mp = entry.toMassProper(key: key) { combined[key] = mp }
        }
        // Legacy propers.json: only add entries that have no DO equivalent
        let doKeys = Set(combined.keys)
        for p in propers {
            if doKeys.contains(p.slug) { continue }
            if hasDOEquivalent(slug: p.slug, doKeys: doKeys) { continue }
            combined[p.slug] = p
        }
        allPropers = combined.values.sorted { $0.slug < $1.slug }
    }

    private func hasDOEquivalent(slug: String, doKeys: Set<String>) -> Bool {
        if slug.hasPrefix("sancti-") {
            return doKeys.contains(String(slug.dropFirst(7)))
        }
        let mappings: [(String, String)] = [
            ("easter-", "pasc"), ("advent-", "adv"), ("lent-", "quad"),
            ("christmas-", "nat"), ("pentecost-", "pent"), ("epiphany-", "epi"),
            ("quinquagesima-", "quadp3-"),
        ]
        for (prefix, doPrefix) in mappings {
            if slug.hasPrefix(prefix) {
                let rest = String(slug.dropFirst(prefix.count))
                if doKeys.contains("\(doPrefix)\(rest)") { return true }
            }
        }
        return false
    }

    // MARK: - Canon variants

    func canonVariant(_ type: String, key: String) -> (lat: String, eng: String)? {
        guard let group = canonVariants[type],
              let entry = group[key],
              let lat = entry["lat"],
              let eng = entry["eng"] else { return nil }
        return (lat, eng)
    }

    // MARK: - Generic bundle loader

    private func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            assertionFailure("\(name).json missing from bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            assertionFailure("Failed to decode \(name).json: \(error)")
            return nil
        }
    }

    // MARK: - Convenience lookups

    func prayer(slug: String) -> Prayer? {
        prayers.first { $0.slug == slug }
    }

    func prayers(in category: String) -> [Prayer] {
        prayers.filter { $0.category == category }
    }

    /// Returns prayers grouped by category, preserving the order in which
    /// categories first appear in the source file (liturgically meaningful).
    func prayersByCategory() -> [(category: String, items: [Prayer])] {
        var seen: [String] = []
        var buckets: [String: [Prayer]] = [:]
        for p in prayers {
            if buckets[p.category] == nil {
                seen.append(p.category)
                buckets[p.category] = []
            }
            buckets[p.category]?.append(p)
        }
        return seen.map { ($0, buckets[$0] ?? []) }
    }
}
