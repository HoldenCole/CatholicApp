import Foundation

// Traditional optional penances the user can select from.
// Stored as a static list; the user's selections persist in UserDefaults.

struct OptionalPenance: Identifiable, Hashable {
    let id: String
    let title: String
    let latin: String
    let desc: String
}

enum OptionalPenances {
    /// Computed so the vernacular overlay applies to the titles and descriptions.
    static var all: [OptionalPenance] { [
        OptionalPenance(
            id: "fast_bread_water",
            title: ContentStore.shared.uiString("penance.fast_bread_water.title", "Bread and Water Fast"),
            latin: "Ieiúnium in pane et aqua",
            desc: ContentStore.shared.uiString("penance.fast_bread_water.desc", "Take only bread and water for one or more meals today.")
        ),
        OptionalPenance(
            id: "no_meat",
            title: ContentStore.shared.uiString("penance.no_meat.title", "Voluntary Abstinence"),
            latin: "Abstinéntia voluntária",
            desc: ContentStore.shared.uiString("penance.no_meat.desc", "Abstain from the flesh of warm-blooded animals, even when not required.")
        ),
        OptionalPenance(
            id: "no_sweets",
            title: ContentStore.shared.uiString("penance.no_sweets.title", "Abstain from Sweets"),
            latin: "Sine dulcibus",
            desc: ContentStore.shared.uiString("penance.no_sweets.desc", "Deny yourself desserts, candy, or sweetened drinks today.")
        ),
        OptionalPenance(
            id: "no_entertainment",
            title: ContentStore.shared.uiString("penance.no_entertainment.title", "Media Fast"),
            latin: "Ieiúnium a spectáculis",
            desc: ContentStore.shared.uiString("penance.no_entertainment.desc", "No social media, television, music, or recreational internet today.")
        ),
        OptionalPenance(
            id: "cold_shower",
            title: ContentStore.shared.uiString("penance.cold_shower.title", "Cold Water Mortification"),
            latin: "Mortificátio córporis",
            desc: ContentStore.shared.uiString("penance.cold_shower.desc", "Take a cold shower or deny yourself hot water as a bodily penance.")
        ),
        OptionalPenance(
            id: "extra_prayers",
            title: ContentStore.shared.uiString("penance.extra_prayers.title", "Additional Prayers"),
            latin: "Oratiónes addítæ",
            desc: ContentStore.shared.uiString("penance.extra_prayers.desc", "Add an extra Rosary decade, chaplet, or 15 minutes of mental prayer.")
        ),
        OptionalPenance(
            id: "almsgiving",
            title: ContentStore.shared.uiString("penance.almsgiving.title", "Almsgiving"),
            latin: "Eleemósyna",
            desc: ContentStore.shared.uiString("penance.almsgiving.desc", "Give to the poor or to a charitable cause today, beyond your usual giving.")
        ),
        OptionalPenance(
            id: "silence",
            title: ContentStore.shared.uiString("penance.silence.title", "Partial Silence"),
            latin: "Siléntium partiále",
            desc: ContentStore.shared.uiString("penance.silence.desc", "Observe silence for a portion of the day, speaking only when necessary.")
        ),
    ] }

    // MARK: - User selection storage

    private static let key = "penance.selected"

    static func selectedIDs() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(arr)
    }

    static func setSelected(_ id: String, selected: Bool) {
        var current = selectedIDs()
        if selected { current.insert(id) } else { current.remove(id) }
        if let data = try? JSONEncoder().encode(Array(current).sorted()) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func selected() -> [OptionalPenance] {
        let ids = selectedIDs()
        return all.filter { ids.contains($0.id) }
    }
}
