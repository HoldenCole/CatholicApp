import Foundation

// Anonymous Gregorian algorithm for computing Easter Sunday.
// Faithful port of prototype/lit-context.js — do not alter without
// cross-checking against the reference implementation, as every
// downstream liturgical date depends on this.
enum Computus {

    /// Returns Easter Sunday of the given Gregorian year.
    static func easterSunday(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.liturgical.date(from: components)!
    }

    /// First Sunday of Advent of the given year. Computed as the Sunday
    /// on or immediately before 27 November — four Sundays before
    /// Christmas Day, inclusive of Christmas Eve's Sunday if applicable.
    static func firstSundayOfAdvent(year: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = 12
        comps.day = 25
        let cal = Calendar.liturgical
        var d = cal.date(from: comps)!
        // Walk back to the nearest Sunday on-or-before Christmas.
        while cal.component(.weekday, from: d) != 1 {
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        // Three more Sundays back to get the First Sunday of Advent.
        d = cal.date(byAdding: .day, value: -21, to: d)!
        return d
    }
}

// Shared liturgical calendar — Gregorian, but always computed in the
// user's local time zone so "today" means the civil day.
extension Calendar {
    static var liturgical: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1 // Sunday
        return c
    }
}

extension Date {
    /// Adds (or subtracts, with a negative) n days. Uses the liturgical
    /// calendar. Crashes only if system clock returns a date before the
    /// Gregorian cutover, which we don't support.
    func addingDays(_ n: Int) -> Date {
        Calendar.liturgical.date(byAdding: .day, value: n, to: self)!
    }

    /// True if self is on the same calendar day as other (ignoring time).
    func isSameDay(as other: Date) -> Bool {
        Calendar.liturgical.isDate(self, inSameDayAs: other)
    }

    /// True if self is on or after the start of other's calendar day.
    func isSameOrAfter(_ other: Date) -> Bool {
        let cal = Calendar.liturgical
        let a = cal.startOfDay(for: self)
        let b = cal.startOfDay(for: other)
        return a >= b
    }

    /// True if self is on or before the start of other's calendar day.
    func isSameOrBefore(_ other: Date) -> Bool {
        let cal = Calendar.liturgical
        let a = cal.startOfDay(for: self)
        let b = cal.startOfDay(for: other)
        return a <= b
    }
}
