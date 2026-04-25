import Foundation

enum ProperCalendar {

    static func properSlug(for date: Date) -> String? {
        let cal = Calendar.liturgical
        let year = cal.component(.year, from: date)
        let easter = Computus.easterSunday(year: year)
        let today = cal.startOfDay(for: date)

        if let slug = sanctoraleSlug(date: today, year: year, cal: cal) {
            return slug
        }

        return temporaleSlug(date: today, easter: easter, year: year, cal: cal)
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

    private static func sanctoraleSlug(date: Date, year: Int, cal: Calendar) -> String? {
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let key = month * 100 + day
        return fixedFeasts[key]
    }

    private static let fixedFeasts: [Int: String] = [
         101: "circumcision",
         106: "epiphany",
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
