import Foundation

enum ProperCalendar {

    static func properSlug(for date: Date) -> String? {
        let cal = Calendar.liturgical
        let year = cal.component(.year, from: date)
        let easter = Computus.easterSunday(year: year)
        let today = cal.startOfDay(for: date)

        if let slug = temporaleSlug(date: today, easter: easter, year: year, cal: cal) {
            return slug
        }

        if let slug = sanctoraleSlug(date: today, year: year, cal: cal) {
            return slug
        }

        return nil
    }

    // MARK: - Temporale (moveable feasts, Easter-relative)

    private static func temporaleSlug(date: Date, easter: Date, year: Int, cal: Calendar) -> String? {
        let easterStart = cal.startOfDay(for: easter)
        let diff = cal.dateComponents([.day], from: easterStart, to: date).day ?? 0

        let firstAdvent = Computus.firstSundayOfAdvent(year: year)
        let prevEaster = Computus.easterSunday(year: year - 1)
        let prevPentecost = cal.startOfDay(for: prevEaster.addingDays(49))

        // Map Easter-relative days to slugs (Sundays first)
        switch diff {
        case -63: return "septuagesima"
        case -56: return "sexagesima"
        case -49: return "quinquagesima"
        case -46: return "ash-wednesday"
        case -42: return "lent-1"
        case -35: return "lent-2"
        case -28: return "lent-3"
        case -21: return "lent-4"
        case -14: return "passion-sunday"
        case  -7: return "palm-sunday"
        case   0: return "easter-sunday"
        case   7: return "easter-1"  // Low Sunday
        case  14: return "easter-2"
        case  21: return "easter-3"
        case  28: return "easter-4"
        case  35: return "easter-5"  // Rogation Sunday
        case  39: return "ascension"
        case  42: return "easter-6"  // Sunday after Ascension
        case  49: return "pentecost-sunday"
        case  56: return "trinity-sunday"
        case  60: return "corpus-christi"
        case  68: return "sacred-heart"
        default: break
        }

        // Sundays after Pentecost
        let trinity = cal.startOfDay(for: easter.addingDays(56))
        if date.isSameOrAfter(trinity) && date.isSameOrBefore(firstAdvent.addingDays(-1)) {
            let dow = cal.component(.weekday, from: date)
            if dow == 1 {
                let weeksAfterPentecost = (cal.dateComponents([.day], from: trinity, to: date).day ?? 0) / 7 + 1
                if weeksAfterPentecost >= 1 && weeksAfterPentecost <= 24 {
                    return "pentecost-\(weeksAfterPentecost)"
                }
            }
        }

        // Sundays after Epiphany
        var epiphComps = DateComponents()
        epiphComps.year = year; epiphComps.month = 1; epiphComps.day = 6
        let epiphany = cal.date(from: epiphComps)!
        let septuagesima = cal.startOfDay(for: easter.addingDays(-63))
        if date.isSameOrAfter(epiphany) && date.isSameOrBefore(septuagesima.addingDays(-1)) {
            let dow = cal.component(.weekday, from: date)
            if dow == 1 {
                let weeks = (cal.dateComponents([.day], from: cal.startOfDay(for: epiphany), to: date).day ?? 0) / 7
                if weeks >= 1 && weeks <= 6 {
                    return "epiphany-\(weeks)"
                }
            }
        }

        // Advent Sundays
        let advent1 = cal.startOfDay(for: firstAdvent)
        if date.isSameOrAfter(advent1) {
            let dow = cal.component(.weekday, from: date)
            if dow == 1 {
                let weeksInAdvent = (cal.dateComponents([.day], from: advent1, to: date).day ?? 0) / 7 + 1
                if weeksInAdvent >= 1 && weeksInAdvent <= 4 {
                    return "advent-\(weeksInAdvent)"
                }
            }
        }

        // Sundays between previous Pentecost's year and current Epiphany
        // (handled by checking previous year's Advent above if needed)

        return nil
    }

    // MARK: - Sanctorale (fixed-date feasts)

    private static func sanctoraleSlug(date: Date, year: Int, cal: Calendar) -> String? {
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let key = month * 100 + day

        return fixedFeasts[key]
    }

    private static let fixedFeasts: [Int: String] = [
        // Format: MMDD -> slug
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
