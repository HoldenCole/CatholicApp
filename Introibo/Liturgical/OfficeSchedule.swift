import Foundation

// MARK: - OfficeSchedule
//
// The single source of truth for "which canonical hour is in effect right now".
// Extracted from OfficeView so the Office tab AND the home-screen widget (and
// any future caller) select the current hour identically. Pure function of its
// inputs — safe to call from a widget extension / background context.
//
// Android mirror:
//   android/.../data/liturgical/OfficeSchedule.kt

enum OfficeSchedule {

    /// The canonical hour in effect at `now`: the nearest hour whose scheduled
    /// time is at or before `now`. Before the first hour of the day (i.e. before
    /// Matutinum at midnight) there is no preceding hour today, so we roll back
    /// to the previous day's Completorium ("completorium"), matching the Office
    /// tab's behaviour.
    static func currentHourSlug(in hours: [Hour], at now: Date = Date()) -> String {
        let cal = Calendar.liturgical
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        var best: (slug: String, diff: Int)?
        for hour in hours {
            let diff = nowMin - (hour.hour * 60 + hour.minute)
            if diff >= 0 {
                if let b = best, diff >= b.diff { continue }
                best = (hour.slug, diff)
            }
        }
        return best?.slug ?? "completorium"
    }
}
