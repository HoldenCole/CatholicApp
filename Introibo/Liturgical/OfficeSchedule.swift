import Foundation

// MARK: - OfficeSchedule
//
// The single source of truth for "which canonical hour is in effect right now".
// Extracted from OfficeView so the Office tab AND the home-screen widget (and
// any future caller) select the current hour identically. Pure function of its
// inputs — safe to call from a widget extension / background context.
//
// This FILE is compiled into BOTH the app target and the IntroiboWidgets
// extension target (see project.yml) — that is the "shared logic" gate: the
// widget cannot drift from the app because they run the same code. It is
// generic over `ScheduledHour` so the extension's lean hour model (decoded
// from the same bundled hours.json) uses the identical selection.
//
// Android mirror:
//   android/.../data/liturgical/OfficeSchedule.kt

/// The minimal shape OfficeSchedule needs: a slug and a scheduled time.
/// `Hour` (app) and `WidgetHour` (extension) both conform.
protocol ScheduledHour {
    var slug: String { get }
    var hour: Int { get }
    var minute: Int { get }
}

enum OfficeSchedule {

    /// The canonical hour in effect at `now`: the nearest hour whose scheduled
    /// time is at or before `now`. Before the first hour of the day (i.e. before
    /// Matutinum at midnight) there is no preceding hour today, so we roll back
    /// to the previous day's Completorium ("completorium"), matching the Office
    /// tab's behaviour.
    static func currentHourSlug<H: ScheduledHour>(in hours: [H], at now: Date = Date()) -> String {
        // Plain Gregorian in the local zone; only hour/minute are read, so this
        // is equivalent to Calendar.liturgical (which lives in the app target).
        let cal = Calendar(identifier: .gregorian)
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
