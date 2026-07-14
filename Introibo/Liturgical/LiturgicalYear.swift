import Foundation

// MARK: - LiturgicalYear (year-overview + upcoming-feasts model)
//
// Pure, side-effect-free models for the year-at-a-glance surfaces: the season
// bands ("where am I in the year"), the major-feast markers, the moveable
// feasts quick-jump, and the upcoming-feasts preview. All liturgical knowledge
// is delegated to the bundled ordo via ContentStore — this file only selects
// and groups.
//
// Android mirror:
//   android/.../data/liturgical/LiturgicalYear.kt

/// A run of consecutive days sharing one liturgical season.
struct SeasonSegment: Identifiable {
    let seasonKey: String   // ordo `season` value ("advent", "lent", ...)
    let label: String       // display label ("Advent", "Lent", ...)
    let startDate: Date
    let endDate: Date
    let dayCount: Int

    var id: String { "\(seasonKey)-\(startDate.timeIntervalSince1970)" }

    static let labels: [String: String] = [
        "advent": "Advent",
        "christmas": "Christmastide",
        "pre-lent": "Pre-Lent",
        "lent": "Lent",
        "easter": "Eastertide",
        "ordinary": "Time after Pentecost",
    ]
}

/// A major feast marked on the year overview.
struct YearMarker: Identifiable {
    let date: Date
    let name: String        // Latin ordo name
    let english: String?    // bundled translation if any
    let color: String       // ordo colour key

    var id: Date { date }
}

enum LiturgicalYearModel {

    // MARK: Season bands

    /// The year's season runs, in date order, under `rite`.
    static func seasons(year: Int, rite: MissalRite, store: ContentStore) -> [SeasonSegment] {
        var segments: [SeasonSegment] = []
        var runKey: String?
        var runStart: Date?
        var runEnd: Date?
        var runDays = 0

        for date in days(ofYear: year) {
            let season = store.ordoForDate(date, rite: rite)?.season ?? "ordinary"
            if season == runKey {
                runEnd = date
                runDays += 1
            } else {
                if let key = runKey, let s = runStart, let e = runEnd {
                    segments.append(SeasonSegment(
                        seasonKey: key,
                        label: SeasonSegment.labels[key] ?? key.capitalized,
                        startDate: s, endDate: e, dayCount: runDays))
                }
                runKey = season
                runStart = date
                runEnd = date
                runDays = 1
            }
        }
        if let key = runKey, let s = runStart, let e = runEnd {
            segments.append(SeasonSegment(
                seasonKey: key,
                label: SeasonSegment.labels[key] ?? key.capitalized,
                startDate: s, endDate: e, dayCount: runDays))
        }
        return segments
    }

    // MARK: Major feasts

    /// Temporal keys always marked: Holy Week core + the paschal-cycle feasts.
    /// (These carry `winner == "temporal"`, so the sanctoral-rank filter below
    /// never sees them.)
    private static let markerTemporalKeys: Set<String> = [
        "quad6-0",   // Palm Sunday
        "quad6-4",   // Maundy Thursday
        "quad6-5",   // Good Friday
        "pasc0-0",   // Easter
        "pasc5-4",   // Ascension
        "pasc7-0",   // Pentecost
        "pent01-0",  // Trinity Sunday
        "pent01-4",  // Corpus Christi
    ]

    /// The year's major feasts under `rite`: first-class sanctoral days plus
    /// the fixed temporal set above. Vigils are not markers.
    static func markers(year: Int, rite: MissalRite, store: ContentStore) -> [YearMarker] {
        var out: [YearMarker] = []
        for date in days(ofYear: year) {
            guard let ordo = store.ordoForDate(date, rite: rite) else { continue }
            let isTemporalMarker = ordo.winner == "temporal"
                && markerTemporalKeys.contains(ordo.winnerKey)
            let isSanctoralMajor = ordo.winner == "sanctoral"
                && ordo.rank >= 6.0
                && !ordo.name.hasPrefix("In Vigilia")
            if isTemporalMarker || isSanctoralMajor {
                out.append(YearMarker(
                    date: date,
                    name: ordo.name,
                    english: store.ordoNameEnglish(ordo.name),
                    color: ordo.color))
            }
        }
        return out
    }

    // MARK: Moveable feasts (quick jump)

    /// Display order for the moveable-feast jump menu.
    static let moveableFeasts: [(label: String, winnerKey: String)] = [
        ("Easter", "pasc0-0"),
        ("Ascension", "pasc5-4"),
        ("Pentecost", "pasc7-0"),
        ("Trinity Sunday", "pent01-0"),
        ("Corpus Christi", "pent01-4"),
        ("Christ the King", "10-du"),
    ]

    /// Resolves the moveable feasts' dates for `year` under `rite`.
    static func moveableDates(year: Int, rite: MissalRite, store: ContentStore) -> [(label: String, date: Date)] {
        var byKey: [String: Date] = [:]
        for date in days(ofYear: year) {
            guard let ordo = store.ordoForDate(date, rite: rite) else { continue }
            if byKey[ordo.winnerKey] == nil {
                byKey[ordo.winnerKey] = date
            }
        }
        return moveableFeasts.compactMap { feast in
            byKey[feast.winnerKey].map { (label: feast.label, date: $0) }
        }
    }

    // MARK: Upcoming feasts

    /// The notable days in the next `days` days (exclusive of today): feasts
    /// of III class and above, vigils, and Ember days.
    static func upcoming(from start: Date = Date(),
                         days window: Int = 14,
                         rite: MissalRite,
                         store: ContentStore) -> [CalendarDay] {
        let cal = Calendar.liturgical
        var out: [CalendarDay] = []
        for offset in 1...window {
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            guard let ordo = store.ordoForDate(date, rite: rite) else { continue }
            let ctx = LiturgicalContext.for(date: date, rite: rite)
            let notable = ordo.rank >= 3.0
                || ordo.name.localizedCaseInsensitiveContains("vigilia")
                || ctx.isEmberDay
            guard notable else { continue }
            out.append(CalendarDay(
                date: date,
                day: cal.component(.day, from: date),
                weekday: cal.component(.weekday, from: date),
                ordo: ordo,
                englishName: store.ordoNameEnglish(ordo.name),
                isToday: false,
                isEmberDay: ctx.isEmberDay))
        }
        return out
    }

    // MARK: Helpers

    /// Every day of `year` in order.
    private static func days(ofYear year: Int) -> [Date] {
        let cal = Calendar.liturgical
        var comps = DateComponents(); comps.year = year; comps.month = 1; comps.day = 1
        guard let start = cal.date(from: comps) else { return [] }
        var out: [Date] = []
        var d = start
        while cal.component(.year, from: d) == year {
            out.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }
}
