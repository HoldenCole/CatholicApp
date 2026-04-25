import Foundation

// Liturgical context for a given date. Mirrors prototype/lit-context.js
// so that the Swift app and the web prototype always agree on what day
// it is in the traditional calendar.

enum LiturgicalSeason: String {
    case advent
    case christmas
    case lent
    case passion
    case pentecost
    case easter
    case perAnnum  // Time after Pentecost / Time after Epiphany
}

enum MysterySet: String {
    case joyful, sorrowful, glorious

    var latinName: String {
        switch self {
        case .joyful:    return "Mystéria Gaudiósa"
        case .sorrowful: return "Mystéria Dolorósa"
        case .glorious:  return "Mystéria Gloriósa"
        }
    }

    var englishName: String {
        switch self {
        case .joyful:    return "Joyful Mysteries"
        case .sorrowful: return "Sorrowful Mysteries"
        case .glorious:  return "Glorious Mysteries"
        }
    }
}

enum MarianAntiphon: String {
    case alma, ave, regina, salve

    var title: String {
        switch self {
        case .alma:   return "Alma Redemptóris Mater"
        case .ave:    return "Ave Regína Cælórum"
        case .regina: return "Regína Cæli"
        case .salve:  return "Salve Regína"
        }
    }
}

struct Penance {
    let title: String
    let latin: String
    let desc: String
    let rubric: String
    let strict: Bool
}

struct LiturgicalContext {
    let date: Date
    let season: LiturgicalSeason
    let colour: LiturgicalColour
    let latinName: String
    let englishName: String
    let feriaLatin: String
    let feriaEnglish: String
    let dayOfWeek: Int  // 0 = Sunday … 6 = Saturday
    let isSunday: Bool
    let isFriday: Bool
    let isLent: Bool
    let marian: MarianAntiphon
    let mystery: MysterySet
    let penance: Penance

    let properSlug: String?

    // Key dates of the liturgical year — useful for other views.
    let easter: Date
    let ashWednesday: Date
    let pentecost: Date
    let trinitySunday: Date
    let firstAdvent: Date

    static func current() -> LiturgicalContext {
        .for(date: Date())
    }

    static func `for`(date now: Date) -> LiturgicalContext {
        let cal = Calendar.liturgical
        let year = cal.component(.year, from: now)

        // Feast anchors.
        let easter = Computus.easterSunday(year: year)
        let ashWed = easter.addingDays(-46)
        let passionStart = easter.addingDays(-14)   // Passion Sunday
        let holyWed = easter.addingDays(-4)
        let pentecost = easter.addingDays(49)
        let trinity = easter.addingDays(56)
        let firstAdvent = Computus.firstSundayOfAdvent(year: year)
        var chrMsComps = DateComponents(); chrMsComps.year = year; chrMsComps.month = 12; chrMsComps.day = 25
        let christmas = cal.date(from: chrMsComps)!
        var candleComps = DateComponents(); candleComps.year = year; candleComps.month = 2; candleComps.day = 2
        let candlemas = cal.date(from: candleComps)!

        // ---- Season detection ----
        let season: LiturgicalSeason
        let colour: LiturgicalColour
        let latinName: String
        let englishName: String

        if now.isSameOrAfter(firstAdvent) && now.isSameOrBefore(christmas.addingDays(-1)) {
            season = .advent
            colour = .violet
            latinName = "Tempus Advéntus"
            englishName = "Advent"
        } else if now.isSameOrAfter(christmas) || now.isSameOrBefore(candlemas.addingDays(-1)) {
            season = .christmas
            colour = .white
            latinName = "Tempus Nativitátis"
            englishName = "Christmastide"
        } else if now.isSameOrAfter(ashWed) && now.isSameOrBefore(easter.addingDays(-1)) {
            if now.isSameOrAfter(passionStart) {
                season = .passion
                colour = .violet
                latinName = "Tempus Passiónis"
                englishName = "Passiontide"
            } else {
                season = .lent
                colour = .violet
                latinName = "Quadragésima"
                englishName = "Lent"
            }
        } else if now.isSameDay(as: pentecost) {
            season = .pentecost
            colour = .red
            latinName = "Pentecóste"
            englishName = "Pentecost"
        } else if now.isSameOrAfter(easter) && now.isSameOrBefore(trinity.addingDays(-1)) {
            season = .easter
            colour = .white
            latinName = "Tempus Paschále"
            englishName = "Eastertide"
        } else if now.isSameOrAfter(trinity) {
            season = .perAnnum
            colour = .green
            latinName = "Tempus post Pentecósten"
            englishName = "Time after Pentecost"
        } else {
            season = .perAnnum
            colour = .green
            latinName = "Tempus post Epiphaníam"
            englishName = "Time after Epiphany"
        }

        // ---- Day-of-week ----
        // Calendar.weekday is 1..7 (Sun..Sat); convert to 0..6.
        let dow = cal.component(.weekday, from: now) - 1
        let isSunday = dow == 0
        let isFriday = dow == 5
        let isLent = (season == .lent || season == .passion)

        // ---- Marian antiphon ----
        let marian: MarianAntiphon
        if now.isSameOrAfter(firstAdvent) || now.isSameOrBefore(candlemas.addingDays(-1)) {
            marian = .alma
        } else if now.isSameOrAfter(candlemas) && now.isSameOrBefore(holyWed) {
            marian = .ave
        } else if now.isSameOrAfter(easter) && now.isSameOrBefore(trinity.addingDays(-1)) {
            marian = .regina
        } else {
            marian = .salve
        }

        // ---- Rosary mystery for today ----
        // Traditional schedule (no Luminous):
        //   Sun/Wed/Sat: Glorious   Mon/Thu: Joyful   Tue/Fri: Sorrowful
        // With seasonal overrides on Sunday:
        //   Advent Sunday    → Joyful
        //   Lent/Passion Sun → Sorrowful
        let byDow: [MysterySet] = [.glorious, .joyful, .sorrowful, .glorious, .joyful, .sorrowful, .glorious]
        var mystery = byDow[dow]
        if isSunday && season == .advent { mystery = .joyful }
        if isSunday && isLent { mystery = .sorrowful }

        // ---- Penance (1962 norms) ----
        let penance: Penance
        if isLent && isFriday {
            penance = Penance(
                title: "Lenten Friday",
                latin: "Feria Sexta in Quadragésima",
                desc: "Abstinence from flesh-meat. Those of fasting age observe the Lenten fast: one full meal and two small collations.",
                rubric: "℟. Quadragésima · Feria Sexta",
                strict: true
            )
        } else if isLent {
            penance = Penance(
                title: "Lenten Fast",
                latin: "Ieiúnium Quadragesimále",
                desc: "Those of fasting age (21–59) observe the Lenten fast: one full meal and two small collations. Wednesdays in Lent are also days of abstinence.",
                rubric: "℟. \(Self.feriaLatin[dow]) in Quadragésima",
                strict: true
            )
        } else if isFriday {
            penance = Penance(
                title: "Friday Abstinence",
                latin: "Feria Sexta",
                desc: "Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.",
                rubric: "℟. Feria Sexta",
                strict: false
            )
        } else if season == .advent && (dow == 3 || dow == 5 || dow == 6) {
            penance = Penance(
                title: "Advent Penance",
                latin: "Tempus Advéntus",
                desc: "A penitential season. Offer voluntary fasts and almsgiving as you prepare for the coming of the Lord.",
                rubric: "℟. \(Self.feriaLatin[dow]) in Advéntu",
                strict: false
            )
        } else if isSunday {
            penance = Penance(
                title: "Day of the Lord",
                latin: "Dies Domínica",
                desc: "No obligation of fasting or abstinence. Rest in the Lord and attend Holy Mass.",
                rubric: "℟. Domínica",
                strict: false
            )
        } else {
            penance = Penance(
                title: "No obligatory penance",
                latin: "Nulla pænitentia obligatória",
                desc: "A free day. Voluntary mortifications are always meritorious — choose a small sacrifice as your daily offering.",
                rubric: "℟. \(Self.feriaLatin[dow])",
                strict: false
            )
        }

        return LiturgicalContext(
            date: now,
            season: season,
            colour: colour,
            latinName: latinName,
            englishName: englishName,
            feriaLatin: Self.feriaLatin[dow],
            feriaEnglish: Self.feriaEnglish[dow],
            dayOfWeek: dow,
            isSunday: isSunday,
            isFriday: isFriday,
            isLent: isLent,
            marian: marian,
            mystery: mystery,
            penance: penance,
            properSlug: ProperCalendar.properSlug(for: now),
            easter: easter,
            ashWednesday: ashWed,
            pentecost: pentecost,
            trinitySunday: trinity,
            firstAdvent: firstAdvent
        )
    }

    private static let feriaLatin = [
        "Domínica", "Feria Secúnda", "Feria Tértia", "Feria Quarta",
        "Feria Quinta", "Feria Sexta", "Sábbato"
    ]
    private static let feriaEnglish = [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
    ]
}

// Format a Date as "the twenty-eighth of March" — matches the
// formatLongDate() helper from lit-context.js.
enum LongDateFormatter {
    static func format(_ date: Date) -> String {
        let cal = Calendar.liturgical
        let day = cal.component(.day, from: date)
        let month = cal.component(.month, from: date)
        let months = ["January","February","March","April","May","June",
                      "July","August","September","October","November","December"]
        let ordinals = [
            "","first","second","third","fourth","fifth","sixth","seventh","eighth","ninth",
            "tenth","eleventh","twelfth","thirteenth","fourteenth","fifteenth","sixteenth",
            "seventeenth","eighteenth","nineteenth","twentieth","twenty-first","twenty-second",
            "twenty-third","twenty-fourth","twenty-fifth","twenty-sixth","twenty-seventh",
            "twenty-eighth","twenty-ninth","thirtieth","thirty-first"
        ]
        return "the \(ordinals[day]) of \(months[month - 1])"
    }
}

// Seasonal countdown and contextual flags for the Today screen.
extension LiturgicalContext {
    var seasonalNote: String? {
        let cal = Calendar.liturgical
        let today = cal.startOfDay(for: date)

        // Lent/Passion countdown to Easter
        if season == .lent || season == .passion {
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: easter)).day ?? 0
            if days == 0 { return nil }
            return "\(days) day\(days == 1 ? "" : "s") until Easter Sunday"
        }

        // Advent countdown to Christmas
        if season == .advent {
            var comps = DateComponents()
            comps.year = cal.component(.year, from: date)
            comps.month = 12; comps.day = 25
            let christmas = cal.date(from: comps)!
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: christmas)).day ?? 0
            if days == 0 { return "Christmas Day" }
            return "\(days) day\(days == 1 ? "" : "s") until Christmas"
        }

        // Easter octave
        if season == .easter {
            let daysSinceEaster = cal.dateComponents([.day], from: cal.startOfDay(for: easter), to: today).day ?? 0
            if daysSinceEaster >= 0 && daysSinceEaster <= 7 {
                return "Octave of Easter — Day \(daysSinceEaster + 1)"
            }
            let daysToPentecost = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: pentecost)).day ?? 0
            if daysToPentecost > 0 && daysToPentecost <= 10 {
                return "\(daysToPentecost) day\(daysToPentecost == 1 ? "" : "s") until Pentecost"
            }
        }

        return nil
    }

    var isFirstFriday: Bool {
        let cal = Calendar.liturgical
        guard cal.component(.weekday, from: date) == 6 else { return false }
        return cal.component(.day, from: date) <= 7
    }

    var isFirstSaturday: Bool {
        let cal = Calendar.liturgical
        guard cal.component(.weekday, from: date) == 7 else { return false }
        return cal.component(.day, from: date) <= 7
    }

    var isEmberDay: Bool {
        // Simplified: Ember days fall on Wed/Fri/Sat of the Ember weeks
        // (after 3rd Sunday of Advent, after Ash Wed, after Pentecost, after Sept 14)
        let dow = dayOfWeek
        guard dow == 3 || dow == 5 || dow == 6 else { return false }
        let cal = Calendar.liturgical
        let weekOfYear = cal.component(.weekOfYear, from: date)

        // Advent ember: 3rd week of Advent
        if season == .advent {
            let advent1Week = cal.component(.weekOfYear, from: firstAdvent)
            if weekOfYear == advent1Week + 2 { return true }
        }

        // Lent ember: week after Ash Wednesday
        if season == .lent {
            let ashWeek = cal.component(.weekOfYear, from: ashWednesday)
            if weekOfYear == ashWeek { return true }
        }

        return false
    }
}
