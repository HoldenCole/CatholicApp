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
        return properFromOrdo(entry)
    }

    func properForDate(_ date: Date, rite: MissalRite = .rite1962) -> MassProper? {
        let entry = ordoForDate(date, rite: rite)
        return properFromOrdo(entry)
    }

    private func properFromOrdo(_ entry: OrdoEntry?) -> MassProper? {
        guard let entry = entry else { return nil }
        let key = entry.winnerKey

        if entry.winner == "sanctoral" {
            if let mp = missalSanctoral[key]?.toMassProper(key: key) { return mp }
            // Christmas: ordo key "12-25" but Mass data is keyed by 12-25m1/m2/m3.
            // Default to the Day Mass (m3).
            if key == "12-25", let mp = missalSanctoral["12-25m3"]?.toMassProper(key: "12-25m3") {
                return mp
            }
        }
        if let mp = missalTempora[key]?.toMassProper(key: key) { return mp }
        if let mp = missalSanctoral[key]?.toMassProper(key: key) { return mp }

        // Try inheritance: e.g., pasc6-4 (post-Ascension Thursday) inherits from pasc5-4 (Ascension).
        if let parent = inheritedTemporalKey(for: key),
           let mp = missalTempora[parent]?.toMassProper(key: parent) {
            return mp
        }

        // Fallback to legacy propers.json by slug
        return propers.first { $0.slug == key }
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
