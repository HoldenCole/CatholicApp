import Foundation

// Vernacular-aware calendar names and date strings. English is the
// literal default; Spanish comes from ui_strings_es.json through
// ContentStore.uiString, so the same tables serve every surface that
// prints a weekday, a month, or a short date (Today, Calendar, share
// sheets, snapshots). The widget extension does not link this file — it
// reads the same keys through WidgetConfigStore.chrome.
//
// Android mirror: data/liturgical/VernacularDates.kt

enum LiturgicalNames {
    static let weekdaysEN = ["Sunday", "Monday", "Tuesday", "Wednesday",
                             "Thursday", "Friday", "Saturday"]
    static let weekdayAbbrevsEN = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    static let monthsEN = ["January", "February", "March", "April", "May", "June",
                           "July", "August", "September", "October", "November", "December"]
    static let monthAbbrevsEN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// Full weekday name; `dow` is 0 = Sunday … 6 = Saturday.
    static func weekday(_ dow: Int) -> String {
        ContentStore.shared.uiString("calendar.weekday.\(dow)", weekdaysEN[dow])
    }
    /// Three-letter weekday abbreviation (upper-case).
    static func weekdayAbbrev(_ dow: Int) -> String {
        ContentStore.shared.uiString("calendar.weekday_abbrev.\(dow)", weekdayAbbrevsEN[dow])
    }
    /// Full month name; `month` is 1…12. Spanish months are lower-case
    /// (as they run inside a date); `capitalized` lifts the first letter
    /// for a heading such as the calendar's month title.
    static func month(_ month: Int, capitalized: Bool = false) -> String {
        let name = ContentStore.shared.uiString("calendar.month.\(month)", monthsEN[month - 1])
        return capitalized ? name.prefix(1).uppercased() + name.dropFirst() : name
    }
    /// Short month name; `month` is 1…12.
    static func monthAbbrev(_ month: Int) -> String {
        ContentStore.shared.uiString("calendar.month_abbrev.\(month)", monthAbbrevsEN[month - 1])
    }
}

/// Fixed-shape date strings that follow the vernacular instead of the
/// device locale. Each shape names its English form; the Spanish form
/// puts the day first and joins with "de" where Spanish does.
enum VernacularDates {
    private static var isSpanish: Bool { ContentStore.shared.vernacular == .spanish }

    private static func parts(_ date: Date) -> (dow: Int, day: Int, month: Int, year: Int) {
        let cal = Calendar.liturgical
        return (cal.component(.weekday, from: date) - 1,
                cal.component(.day, from: date),
                cal.component(.month, from: date),
                cal.component(.year, from: date))
    }

    /// "Sep 8" · "8 sep"
    static func shortDayMonth(_ date: Date) -> String {
        let p = parts(date)
        return isSpanish ? "\(p.day) \(LiturgicalNames.monthAbbrev(p.month))"
                         : "\(LiturgicalNames.monthAbbrev(p.month)) \(p.day)"
    }
    /// "September 8" · "8 de septiembre"
    static func longDayMonth(_ date: Date) -> String {
        let p = parts(date)
        return isSpanish ? "\(p.day) de \(LiturgicalNames.month(p.month))"
                         : "\(LiturgicalNames.month(p.month)) \(p.day)"
    }
    /// "Mon 8 Sep" · "lun 8 sep"
    static func weekdayDayMonthAbbrev(_ date: Date) -> String {
        let p = parts(date)
        let wd = LiturgicalNames.weekdayAbbrev(p.dow)
        let wdCased = isSpanish ? wd.lowercased() : wd.prefix(1) + wd.dropFirst().lowercased()
        return "\(wdCased) \(p.day) \(LiturgicalNames.monthAbbrev(p.month))"
    }
    /// "Monday, September 8" · "lunes, 8 de septiembre"
    static func weekdayLongDate(_ date: Date) -> String {
        let p = parts(date)
        let wd = LiturgicalNames.weekday(p.dow)
        return isSpanish ? "\(wd.lowercased()), \(p.day) de \(LiturgicalNames.month(p.month))"
                         : "\(wd), \(LiturgicalNames.month(p.month)) \(p.day)"
    }
    /// "Monday 8 September" · "lunes 8 de septiembre"
    static func weekdayDayMonth(_ date: Date) -> String {
        let p = parts(date)
        let wd = LiturgicalNames.weekday(p.dow)
        return isSpanish ? "\(wd.lowercased()) \(p.day) de \(LiturgicalNames.month(p.month))"
                         : "\(wd) \(p.day) \(LiturgicalNames.month(p.month))"
    }
    /// "September 2026" · "Septiembre 2026"
    static func monthYear(_ date: Date) -> String {
        let p = parts(date)
        return "\(LiturgicalNames.month(p.month, capitalized: true)) \(p.year)"
    }
    /// "September" · "Septiembre"
    static func monthName(_ date: Date) -> String {
        LiturgicalNames.month(parts(date).month, capitalized: true)
    }
}
