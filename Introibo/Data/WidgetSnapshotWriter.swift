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

        // Localized widget chrome for the extension (its only channel to the
        // in-app vernacular setting). Hour vernacular names ride along so the
        // office widget's subtitle follows the language; the Latin names do
        // not pass through here and stay Latin in every vernacular.
        if VernacularLanguage.current() == .spanish {
            var chrome: [String: String] = [:]
            for key in ["widget.label.office", "widget.label.morning",
                        "widget.label.midday", "widget.label.evening",
                        "widget.tap_to_pray", "widget.stale",
                        "widget.reading.introit", "widget.reading.collect",
                        "widget.reading.epistle", "widget.reading.gospel"] {
                let es = store.uiString(key, "")
                if !es.isEmpty { chrome[key] = es }
            }
            for hour in store.hours {
                chrome["hour.\(hour.slug)"] = hour.eng
            }
            WidgetConfigStore.setChrome(chrome)
        } else {
            WidgetConfigStore.setChrome([:])
        }

        let cal = Calendar.liturgical
        var out: [WidgetDaySnapshot] = []
        out.reserveCapacity(windowDays)

        // Season runs for the years the window touches, so each day can carry
        // its position within the current season ("day N of M" — the Church's
        // calendar, never the user's behaviour).
        var seasonsByYear: [Int: [SeasonSegment]] = [:]
        func seasonPosition(of date: Date) -> (day: Int, length: Int)? {
            let day0 = cal.startOfDay(for: date)
            let year = cal.component(.year, from: day0)
            if seasonsByYear[year] == nil {
                seasonsByYear[year] = LiturgicalYearModel.seasons(year: year, rite: rite, store: store)
            }
            guard let seg = seasonsByYear[year]?.first(where: {
                $0.startDate <= day0 && day0 <= $0.endDate
            }) else { return nil }
            let dayIndex = (cal.dateComponents([.day], from: seg.startDate, to: day0).day ?? 0) + 1
            return (dayIndex, seg.dayCount)
        }

        for offset in 0..<windowDays {
            guard let date = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
            let ordo = store.ordoForDate(date, rite: rite)
            let ctx = LiturgicalContext.for(date: date, rite: rite)
            guard let proper = store.properForDate(date, rite: rite) else { continue }
            let notable = (ordo?.rank ?? 0) >= 3.0
                || (ordo?.name.localizedCaseInsensitiveContains("vigilia") ?? false)
                || ctx.isEmberDay
            let position = seasonPosition(of: date)
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
                gospelRef: proper.gospel.ref,
                rank: ordo?.rank,
                sanctoral: ordo?.winner == "sanctoral",
                notable: notable,
                seasonDay: position?.day,
                seasonLength: position?.length
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
