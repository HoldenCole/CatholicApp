import Foundation

// MARK: - LiturgicalCalendar (month-grid model)
//
// Pure, side-effect-free model for the browsable liturgical calendar. Given a
// (year, month, rite) it produces the Sunday-first grid the UI lays out: the
// number of leading blank cells, then one `CalendarDay` per day-of-month, each
// carrying its resolved ordo entry. All liturgical knowledge is delegated to
// `ContentStore.ordoForDate` — this file only does calendar geometry.
//
// Android mirror:
//   android/.../data/liturgical/LiturgicalCalendar.kt
// Both platforms read the SAME bundled ordo tables, so a given (year, month,
// rite) yields the same feast/colour per day on each platform by construction.

/// One day cell in a month grid.
struct CalendarDay: Identifiable {
    let date: Date
    let day: Int             // day-of-month, 1...31
    let weekday: Int         // 1=Sun .. 7=Sat (Calendar.liturgical weekday)
    let ordo: OrdoEntry?     // nil only if the date is outside the bundled ordo
    let englishName: String? // full English translation of ordo.name, if bundled
    let isToday: Bool
    /// Ember day under the rite (from LiturgicalContext at build time).
    var isEmberDay: Bool = false
    /// Strict fast/abstinence under the user's penance discipline (build time).
    var penanceStrict: Bool = false

    var id: Int { day }

    /// Vigil day (from the ordo title — "In Vigilia …" / "Sabbato in Vigilia …").
    var isVigil: Bool {
        ordo?.name.localizedCaseInsensitiveContains("vigilia") ?? false
    }

    /// A day within (or the day of) an octave, from the ordo title.
    var isOctaveDay: Bool {
        guard let n = ordo?.name.lowercased() else { return false }
        return n.contains("octav")   // "in octava", "infra octavam", "die octavæ"
    }

    /// Display colour for the cell's pip; nil when there is no ordo entry.
    var colour: LiturgicalColour? {
        ordo.map { LiturgicalColour.from(ordoColor: $0.color) }
    }

    /// Short feast/feria label for the cell (full ordo name; the view truncates).
    var label: String? { ordo?.name }

    /// A 1st- or 2nd-class day (rank >= 5) — the view emphasises these.
    var isMajor: Bool { (ordo?.rank ?? 0) >= 5.0 }

    var isSunday: Bool { weekday == 1 }

    /// Three-letter weekday abbreviation (SUN, MON, … SAT).
    var weekdayAbbrev: String { Self.abbrevs[weekday - 1] }
    private static let abbrevs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    /// Full English weekday name.
    var weekdayName: String { Self.dayNames[weekday - 1] }
    private static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// The English line shown beneath the Latin name — the full feast/feria
    /// translation when bundled, else just the weekday.
    var englishLine: String { englishName ?? weekdayName }

    /// English season label (for the inline season dividers).
    var seasonLabel: String? { ordo.flatMap { Self.seasonLabels[$0.season] } }
    private static let seasonLabels: [String: String] = [
        "advent": "Advent",
        "christmas": "Christmastide",
        "lent": "Lent",
        "easter": "Eastertide",
        "ordinary": "Ordinary Time",
        "pre-lent": "Pre-Lent",
    ]
}

/// A single month laid out for display.
struct CalendarMonth {
    let year: Int
    let month: Int           // 1...12
    let title: String        // "May 2026"
    let leadingBlanks: Int    // empty cells before day 1 (Sunday-first week)
    let days: [CalendarDay]

    /// Builds the grid for `year`/`month` under `rite`. `today` is injectable
    /// for testing; defaults to now. `month` is 1-based.
    static func build(year: Int,
                      month: Int,
                      rite: MissalRite,
                      store: ContentStore,
                      today: Date = Date(),
                      discipline: PenanceDiscipline = .discipline1962) -> CalendarMonth {
        let cal = Calendar.liturgical
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let firstOfMonth = cal.date(from: comps) ?? Date()

        // weekday is 1...7 (Sun...Sat); Sunday-first grid → blanks = weekday - 1.
        let leading = cal.component(.weekday, from: firstOfMonth) - 1
        let dayCount = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var days: [CalendarDay] = []
        days.reserveCapacity(dayCount)
        for d in 1...dayCount {
            var dc = comps
            dc.day = d
            let date = cal.date(from: dc) ?? firstOfMonth
            let ordo = store.ordoForDate(date, rite: rite)
            let ctx = LiturgicalContext.for(date: date, rite: rite, discipline: discipline)
            days.append(CalendarDay(
                date: date,
                day: d,
                weekday: cal.component(.weekday, from: date),
                ordo: ordo,
                englishName: ordo.flatMap { store.ordoNameEnglish($0.name) },
                isToday: cal.isDate(date, inSameDayAs: today),
                isEmberDay: ctx.isEmberDay,
                penanceStrict: ctx.penance.strict
            ))
        }

        return CalendarMonth(
            year: year,
            month: month,
            title: Self.titleFormatter.string(from: firstOfMonth),
            leadingBlanks: leading,
            days: days
        )
    }

    /// "May 2026" — English month name + year, locale-fixed for stable display.
    private static let titleFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.liturgical
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "LLLL yyyy"
        return df
    }()
}
