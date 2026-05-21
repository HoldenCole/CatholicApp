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
        return officeAssembler.assemble(template: template, context: .current())
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
        }
        if let mp = missalTempora[key]?.toMassProper(key: key) { return mp }
        if let mp = missalSanctoral[key]?.toMassProper(key: key) { return mp }

        // Fallback to legacy propers.json by slug
        return propers.first { $0.slug == key }
    }

    // MARK: - All searchable propers (combined old + new)

    private(set) var allPropers: [MassProper] = []

    private func buildAllPropers() {
        var combined: [String: MassProper] = [:]
        // DivinumOfficium data takes priority
        for (key, entry) in missalTempora {
            if let mp = entry.toMassProper(key: key) { combined[key] = mp }
        }
        for (key, entry) in missalSanctoral {
            if let mp = entry.toMassProper(key: key) { combined[key] = mp }
        }
        // Legacy propers.json fills gaps only
        for p in propers {
            if combined[p.slug] == nil { combined[p.slug] = p }
        }
        allPropers = combined.values.sorted { $0.slug < $1.slug }
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
