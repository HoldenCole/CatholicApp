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
    }

    func proper(slug: String) -> MassProper? {
        propers.first { $0.slug == slug }
    }

    func hour(slug: String) -> Hour? {
        hours.first { $0.slug == slug }
    }

    func mysterySet(slug: String) -> MysterySetData? {
        mysterySets.first { $0.slug == slug }
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
