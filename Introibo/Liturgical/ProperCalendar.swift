import Foundation

enum ProperCalendar {

    // NOTE: Feast transfers (Item 28) — Full transfer logic for impeded
    // feasts (e.g. when a 2nd-class feast falls on a 1st-class Sunday) is
    // not yet implemented. This requires a multi-day look-ahead algorithm
    // that evaluates rank precedence and finds the next open slot. Planned
    // for a future release. For now, the higher-ranked day simply wins and
    // the impeded feast is omitted.

    static func properSlug(for date: Date, rite: MissalRite = .rite1962) -> String? {
        let cal = Calendar.liturgical
        let year = cal.component(.year, from: date)
        let easter = Computus.easterSunday(year: year)
        let today = cal.startOfDay(for: date)
        let dow = cal.component(.weekday, from: today) - 1 // 0=Sun..6=Sat

        // High-priority moveable feasts override everything
        if let slug = moveableSlug(date: today, easter: easter, cal: cal) {
            return slug
        }

        // Fixed sanctorale feasts (high-rank saints in fixedFeasts dictionary)
        if let slug = sanctoraleSlug(date: today, year: year, cal: cal, rite: rite) {
            return slug
        }

        // On Sundays, the temporal cycle takes precedence over generic saints
        if dow == 0 {
            if let slug = temporaleSlug(date: today, easter: easter, year: year, cal: cal) {
                return slug
            }
        }

        // On weekdays, check if a saint's feast proper exists for this date
        // Saints' feasts override ferial days in the temporal cycle
        let month = cal.component(.month, from: today)
        let day = cal.component(.day, from: today)
        let sanctiSlug = String(format: "sancti-%02d-%02d", month, day)
        let propers = ContentStore.shared.propers
        if propers.contains(where: { $0.slug == sanctiSlug }) {
            return sanctiSlug
        }

        // Temporal cycle for weekdays without a saint's feast
        if let slug = temporaleSlug(date: today, easter: easter, year: year, cal: cal) {
            return slug
        }

        // Final fallback
        return sanctiSlug
    }

    static func properSlugWithFallback(for date: Date, store: [String], rite: MissalRite = .rite1962) -> String? {
        if let slug = properSlug(for: date, rite: rite), store.contains(slug) {
            return slug
        }
        let cal = Calendar.liturgical
        let dow = cal.component(.weekday, from: date) - 1
        if dow > 0 {
            let lastSunday = date.addingDays(-dow)
            if let slug = properSlug(for: lastSunday, rite: rite), store.contains(slug) {
                return slug
            }
        }
        return properSlug(for: date, rite: rite)
    }

    // Moveable feasts that take precedence over fixed sanctorale entries
    private static func moveableSlug(date: Date, easter: Date, cal: Calendar) -> String? {
        let easterStart = cal.startOfDay(for: easter)
        let diff = cal.dateComponents([.day], from: easterStart, to: date).day ?? 0

        switch diff {
        case 38:  return "vigil-ascension"
        case 39:  return "ascension"
        case 48:  return "vigil-pentecost"
        case 49:  return "pentecost-sunday"
        case 60:  return "corpus-christi"
        case 68:  return "sacred-heart"
        default:  return nil
        }
    }

    private static func temporaleSlug(date: Date, easter: Date, year: Int, cal: Calendar) -> String? {
        let easterStart = cal.startOfDay(for: easter)
        let diff = cal.dateComponents([.day], from: easterStart, to: date).day ?? 0
        let dow = cal.component(.weekday, from: date) - 1 // 0=Sun..6=Sat
        let firstAdvent = Computus.firstSundayOfAdvent(year: year)

        // Easter Octave (week 0): Easter Sunday through Saturday
        if diff >= 0 && diff <= 6 {
            if diff == 0 { return "easter-sunday" }
            return "easter-0-\(diff)"
        }

        // Easter weeks 1-7 (Low Sunday through Pentecost vigil)
        if diff >= 7 && diff <= 48 {
            let week = diff / 7
            let dayInWeek = diff % 7
            if dayInWeek == 0 { return "easter-\(week)" }
            return "easter-\(week)-\(dayInWeek)"
        }

        // Pentecost Sunday + Octave
        if diff == 49 { return "easter-7" }
        if diff >= 50 && diff <= 55 {
            return "easter-7-\(diff - 49)"
        }

        // Trinity Sunday
        if diff == 56 { return "trinity-sunday" }

        // Sundays + weekdays after Pentecost
        let trinity = cal.startOfDay(for: easter.addingDays(56))
        if date.isSameOrAfter(trinity) && date.isSameOrBefore(firstAdvent.addingDays(-1)) {
            let daysAfterTrinity = cal.dateComponents([.day], from: trinity, to: date).day ?? 0
            let week = daysAfterTrinity / 7 + 1
            let dayInWeek = daysAfterTrinity % 7
            if week >= 1 && week <= 24 {
                if dayInWeek == 0 { return "pentecost-\(week)" }
                return "pentecost-\(week)-\(dayInWeek)"
            }
        }

        // Pre-Lent
        if diff >= -63 && diff <= -50 {
            let prelentDay = diff + 63
            let week = prelentDay / 7 + 1 // 1=Sept, 2=Sexag, 3=Quinq
            let dayInWeek = prelentDay % 7
            let names = [1: "septuagesima", 2: "sexagesima", 3: "quinquagesima"]
            if let name = names[week] {
                if dayInWeek == 0 { return name }
                return "\(name)-\(dayInWeek)"
            }
        }

        // Ash Wednesday through Lent
        if diff == -46 { return "quinquagesima-3" } // Ash Wednesday
        if diff >= -45 && diff <= -43 {
            return "quinquagesima-\(diff + 49)"
        }

        // Lent weeks 1-4
        if diff >= -42 && diff <= -15 {
            let lentDay = diff + 42
            let week = lentDay / 7 + 1
            let dayInWeek = lentDay % 7
            if week >= 1 && week <= 4 {
                if dayInWeek == 0 { return "lent-\(week)" }
                return "lent-\(week)-\(dayInWeek)"
            }
        }

        // Passion week (week 5)
        if diff >= -14 && diff <= -8 {
            let dayInWeek = diff + 14
            if dayInWeek == 0 { return "passion-sunday" }
            return "lent-5-\(dayInWeek)"
        }

        // Holy Week
        if diff >= -7 && diff <= -1 {
            let dayInWeek = diff + 7
            if dayInWeek == 0 { return "palm-sunday" }
            let names = [1: "holy-week-1", 2: "holy-week-2", 3: "holy-week-3",
                         4: "holy-thursday", 5: "good-friday", 6: "holy-saturday"]
            return names[dayInWeek]
        }

        // Epiphany season
        var epiphComps = DateComponents()
        epiphComps.year = year; epiphComps.month = 1; epiphComps.day = 6
        let epiphany = cal.date(from: epiphComps)!
        let septuagesima = cal.startOfDay(for: easter.addingDays(-63))
        if date.isSameOrAfter(epiphany) && date.isSameOrBefore(septuagesima.addingDays(-1)) {
            let daysAfterEpiph = cal.dateComponents([.day], from: cal.startOfDay(for: epiphany), to: date).day ?? 0
            if daysAfterEpiph > 0 {
                // Find which Sunday week we're in
                let nextSunday = daysAfterEpiph + (7 - ((daysAfterEpiph - 1) % 7 + 1)) % 7
                let week = nextSunday / 7
                if week >= 1 && week <= 6 {
                    if dow == 0 { return "epiphany-\(week)" }
                    return "epiphany-\(week)-\(dow)"
                }
            }
        }

        // Advent
        let advent1 = cal.startOfDay(for: firstAdvent)
        if date.isSameOrAfter(advent1) {
            let daysInAdvent = cal.dateComponents([.day], from: advent1, to: date).day ?? 0
            let week = daysInAdvent / 7 + 1
            let dayInWeek = daysInAdvent % 7
            if week >= 1 && week <= 4 {
                if dayInWeek == 0 { return "advent-\(week)" }
                return "advent-\(week)-\(dayInWeek)"
            }
        }

        return nil
    }

    private static func sanctoraleSlug(date: Date, year: Int, cal: Calendar, rite: MissalRite = .rite1962) -> String? {
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let dow = cal.component(.weekday, from: date) // 1=Sun..7=Sat

        // Christ the King: last Sunday of October (rank 1, overrides sanctorale)
        if month == 10 && dow == 1 && day >= 25 {
            return "christ-king"
        }

        // Sundays after Christmas
        // 1st Sunday after Christmas: the Sunday in the Dec 26–31 window
        if month == 12 && day >= 26 && dow == 1 {
            return "christmas-1"
        }
        // 2nd Sunday after Christmas: the Sunday between Jan 2–5
        if month == 1 && day >= 2 && day <= 5 && dow == 1 {
            return "christmas-2"
        }

        let key = month * 100 + day

        // Pre-1955: St. Joseph the Worker (May 1) did not exist; instead
        // May 1 was the feast of Sts. Philip and James, Apostles.
        if key == 501 && rite == .pre1955 {
            return "sts-philip-james"
        }

        if let feast = fixedFeasts[key] {
            return feast
        }
        return nil
    }

    private static let fixedFeasts: [Int: String] = [
         101: "circumcision",
         106: "epiphany",
         501: "st-joseph-worker",
         202: "purification",
         319: "st-joseph",
         325: "annunciation",
         624: "nativity-john-baptist",
         629: "sts-peter-paul",
         815: "assumption",
         908: "nativity-bvm",
        1001: "holy-rosary",
        1101: "all-saints",
        1102: "all-souls",
        1208: "immaculate-conception",
        1225: "christmas",
        1226: "st-stephen",
        1227: "st-john-evangelist",
        1228: "holy-innocents",
    ]
}
