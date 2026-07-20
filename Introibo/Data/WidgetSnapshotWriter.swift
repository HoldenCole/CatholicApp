import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - WidgetSnapshotWriter (app target only)
//
// Precomputes the rolling window of WidgetDaySnapshots the widget extension
// renders (the extension can't load the missal corpus itself — see
// WidgetDaySnapshot). Called on app launch and whenever the rite or language
// setting changes; cheap (~30 ordo lookups + proper resolutions).

enum WidgetSnapshotWriter {

    static let windowDays = 30

    /// Rebuild the snapshot window from today under the user's settings and
    /// hand it to the shared store. Safe to call from any thread.
    static func refresh(store: ContentStore = .shared) {
        let riteRaw = UserDefaults.standard.string(forKey: SettingsKey.rite) ?? ""
        let rite = MissalRite(rawValue: riteRaw) ?? .rite1962
        let langRaw = UserDefaults.standard.string(forKey: SettingsKey.language) ?? ""
        let lang = LanguageMode(rawValue: langRaw) ?? .both

        let cal = Calendar.liturgical
        var out: [WidgetDaySnapshot] = []
        out.reserveCapacity(windowDays)

        for offset in 0..<windowDays {
            guard let date = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
            let ordo = store.ordoForDate(date, rite: rite)
            let ctx = LiturgicalContext.for(date: date, rite: rite)
            guard let proper = store.properForDate(date, rite: rite) else { continue }
            out.append(WidgetDaySnapshot(
                date: WidgetSnapshotStore.dateKey(date),
                name: ordo?.name ?? ctx.feriaLatin,
                english: ordo.flatMap { store.ordoNameEnglish($0.name) },
                color: ordo?.color ?? "green",
                season: ctx.englishName,
                introitLat: proper.introit.lat,
                introitEng: proper.introit.eng,
                introitRef: proper.introit.ref,
                collectLat: proper.collect.lat,
                collectEng: proper.collect.eng,
                epistleLat: proper.epistle.lat,
                epistleEng: proper.epistle.eng,
                epistleRef: proper.epistle.ref,
                gospelLat: proper.gospel.lat,
                gospelEng: proper.gospel.eng,
                gospelRef: proper.gospel.ref
            ))
        }

        WidgetSnapshotStore.save(out)
        WidgetConfigStore.defaults.set(
            lang == .latinOnly ? "latin" : "english",
            forKey: WidgetSnapshotStore.langKey
        )
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
