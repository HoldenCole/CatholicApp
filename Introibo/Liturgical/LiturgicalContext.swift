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
    case alma, ave, regina, salve, suppressed

    var title: String {
        switch self {
        case .alma:       return "Alma Redemptóris Mater"
        case .ave:        return "Ave Regína Cælórum"
        case .regina:     return "Regína Cæli"
        case .salve:      return "Salve Regína"
        case .suppressed: return ""
        }
    }

    /// Whether the antiphon should be displayed. During Triduum, no Marian
    /// antiphon is said at Compline.
    var isSuppressed: Bool { self == .suppressed }
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
    let temporalKey: String?

    // Key dates of the liturgical year — useful for other views.
    let easter: Date
    let ashWednesday: Date
    let pentecost: Date
    let trinitySunday: Date
    let firstAdvent: Date

    static func current() -> LiturgicalContext {
        let riteRaw = UserDefaults.standard.string(forKey: SettingsKey.rite) ?? MissalRite.rite1962.rawValue
        let rite = MissalRite(rawValue: riteRaw) ?? .rite1962
        let discRaw = UserDefaults.standard.string(forKey: SettingsKey.penance) ?? PenanceDiscipline.discipline1962.rawValue
        let disc = PenanceDiscipline(rawValue: discRaw) ?? .discipline1962
        return .for(date: Date(), rite: rite, discipline: disc)
    }

    static func `for`(date now: Date, rite: MissalRite = .rite1962, discipline: PenanceDiscipline = .discipline1962) -> LiturgicalContext {
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
        // Boundary rules (Breviary of Pius V, 1569; 1962 rubrics):
        //  - Alma: from First Vespers of Advent I (= Saturday before Advent I)
        //    through Compline of Feb 1. Feb 2 (Candlemas) belongs to Ave.
        //  - Ave: from Compline of Feb 2 through Compline of Holy Wednesday.
        //  - Triduum (Maundy Thu / Good Fri / Holy Sat): no Marian antiphon
        //    is said at Compline (suppressed).
        //  - Regina Caeli: Easter Sunday through the day before Trinity Sunday.
        //  - Salve: Trinity Sunday through Friday before Advent I.
        let marian: MarianAntiphon
        let triduumStart = easter.addingDays(-3)   // Maundy Thursday
        let triduumEnd = easter.addingDays(-1)     // Holy Saturday
        let almaStart = firstAdvent.addingDays(-1) // Saturday before Advent I (First Vespers)
        if now.isSameOrAfter(triduumStart) && now.isSameOrBefore(triduumEnd) {
            marian = .suppressed   // Triduum: no Marian antiphon at Compline
        } else if now.isSameOrAfter(almaStart) || now.isSameOrBefore(candlemas.addingDays(-1)) {
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

        // ---- Penance (discipline-aware) ----
        let penance = Self.computePenance(
            discipline: discipline, season: season,
            dow: dow, isSunday: isSunday, isFriday: isFriday, isLent: isLent,
            date: now, easter: easter, pentecost: pentecost,
            firstAdvent: firstAdvent, cal: cal
        )

        let temporal = Self.computeTemporalKey(
            date: now, easter: easter, ashWed: ashWed,
            pentecost: pentecost, trinity: trinity,
            firstAdvent: firstAdvent, christmas: christmas,
            cal: cal
        )

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
            properSlug: ProperCalendar.properSlug(for: now, rite: rite),
            temporalKey: temporal,
            easter: easter,
            ashWednesday: ashWed,
            pentecost: pentecost,
            trinitySunday: trinity,
            firstAdvent: firstAdvent
        )
    }

    /// Computes the DivinumOfficium-style temporal key for the given date.
    /// Maps the liturgical calendar position to codes like "pasc5-4" (Ascension),
    /// "adv1-0" (1st Sunday of Advent), "quad3-3" (Wednesday of Lent week 3), etc.
    private static func computeTemporalKey(
        date: Date, easter: Date, ashWed: Date,
        pentecost: Date, trinity: Date,
        firstAdvent: Date, christmas: Date,
        cal: Calendar
    ) -> String? {
        let today = cal.startOfDay(for: date)

        // Easter season: Pasc{week}-{dow}  (Easter Sunday = Pasc0-0)
        if today >= cal.startOfDay(for: easter) && today < cal.startOfDay(for: pentecost.addingDays(7)) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: easter), to: today).day ?? 0
            return "pasc\(days / 7)-\(days % 7)"
        }

        // Pre-Lent (Septuagesima) through Lent
        // DO numbering: Quadp1-0 = Septuagesima Sunday,
        // Quad1-0 = 1st Sunday of Lent, Ash Wed = Quadp3-3
        let septuagesima = ashWed.addingDays(-17)
        let firstSunLent = ashWed.addingDays(4) // Ash Wed is always a Wednesday

        if today >= cal.startOfDay(for: firstSunLent) && today < cal.startOfDay(for: easter) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: firstSunLent), to: today).day ?? 0
            return "quad\(days / 7 + 1)-\(days % 7)"
        }

        if today >= cal.startOfDay(for: septuagesima) && today < cal.startOfDay(for: firstSunLent) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: septuagesima), to: today).day ?? 0
            return "quadp\(days / 7 + 1)-\(days % 7)"
        }

        // Advent: Adv{week}-{dow} (1st Sunday of Advent = Adv1-0)
        if today >= cal.startOfDay(for: firstAdvent) && today < cal.startOfDay(for: christmas) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: firstAdvent), to: today).day ?? 0
            let week = (days / 7) + 1
            let day = days % 7
            return "adv\(week)-\(day)"
        }

        // After Pentecost: Pent{week:02d}-{dow}
        if today >= cal.startOfDay(for: trinity) && today < cal.startOfDay(for: firstAdvent) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: trinity), to: today).day ?? 0
            let week = (days / 7) + 1
            let day = days % 7
            return String(format: "pent%02d-%d", week, day)
        }

        // After Epiphany
        var epiComps = DateComponents()
        epiComps.year = cal.component(.year, from: date)
        epiComps.month = 1; epiComps.day = 6
        let epiphany = cal.date(from: epiComps)!
        let epi1Sun = Self.nextSunday(after: epiphany, cal: cal)
        if today >= cal.startOfDay(for: epi1Sun) && today < cal.startOfDay(for: septuagesima) {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: epi1Sun), to: today).day ?? 0
            let week = (days / 7) + 1
            let day = days % 7
            return "epi\(week)-\(day)"
        }

        // Christmas to Epiphany
        if today >= cal.startOfDay(for: christmas) || today < cal.startOfDay(for: epi1Sun) {
            let christmasDay = cal.startOfDay(for: christmas)
            if today >= christmasDay {
                let days = cal.dateComponents([.day], from: christmasDay, to: today).day ?? 0
                return "nat\(days)"
            }
        }

        return nil
    }

    private static func nextSunday(after date: Date, cal: Calendar) -> Date {
        var d = date
        while cal.component(.weekday, from: d) != 1 {
            d = d.addingDays(1)
        }
        return d
    }

    // MARK: - Discipline-aware penance computation
    //
    // Three supported disciplines:
    //  .discipline1962 — CIC 1983 / Paenitemini 1966 as applied in traditionalist
    //     practice: Friday abstinence year-round; Lenten fast on weekdays
    //     (ages 21–59 fasting, 14+ abstinence).
    //  .discipline1917 — 1917 Code of Canon Law (canons 1250–1254): adds
    //     Ember-day fast+abstinence; Saturday abstinence in Lent; vigil fasts
    //     (Christmas Eve, Pentecost vigil, Assumption vigil, All Saints vigil);
    //     Advent Fridays+Saturdays are abstinence days.
    //  .strict — Pre-Pius XII (pre-1953): everything in 1917, plus Advent
    //     Wednesdays & Fridays are fast+abstinence days; no upper age limit
    //     on the fast.

    private static func computePenance(
        discipline: PenanceDiscipline,
        season: LiturgicalSeason,
        dow: Int, isSunday: Bool, isFriday: Bool, isLent: Bool,
        date: Date, easter: Date, pentecost: Date,
        firstAdvent: Date, cal: Calendar
    ) -> Penance {
        let isSaturday = dow == 6
        let isWednesday = dow == 3

        // Sundays: never a day of obligatory penance in any discipline.
        if isSunday {
            return Penance(
                title: "Day of the Lord", latin: "Dies Domínica",
                desc: "No obligation of fasting or abstinence. Rest in the Lord and attend Holy Mass.",
                rubric: "℟. Domínica", strict: false
            )
        }

        // Ember days: fast + abstinence under 1917/strict (Wed/Fri/Sat of Ember weeks)
        // Under 1962 they are penitential but not obligatory fast days.
        if discipline != .discipline1962 {
            if isEmberDate(date: date, easter: easter, pentecost: pentecost,
                           firstAdvent: firstAdvent, cal: cal, dow: dow) {
                return Penance(
                    title: "Ember Day: Fast & Abstinence",
                    latin: "Quattuor Témporum",
                    desc: discipline == .strict
                        ? "Fast (one full meal, no upper age limit) and complete abstinence from flesh-meat."
                        : "Fast (one full meal and two collations, ages 21–59) and abstinence from flesh-meat.",
                    rubric: "℟. Quattuor Témporum",
                    strict: true
                )
            }
        }

        // Vigils: fast days under 1917/strict
        if discipline != .discipline1962 {
            if isVigilFast(date: date, easter: easter, pentecost: pentecost, cal: cal) {
                return Penance(
                    title: "Vigil: Fast & Abstinence",
                    latin: "Vigília: Ieiúnium",
                    desc: discipline == .strict
                        ? "Fast (one full meal, no upper age limit) and abstinence."
                        : "Fast (one full meal and two collations, ages 21–59) and abstinence.",
                    rubric: "℟. Vigília",
                    strict: true
                )
            }
        }

        // Lent
        if isLent {
            let fastDesc = discipline == .strict
                ? "Fast: one full meal (no upper age limit). Two small collations permitted."
                : "Fast: one full meal and two small collations (ages 21–59)."
            if isFriday {
                return Penance(
                    title: "Lenten Friday: Fast & Abstinence",
                    latin: "Feria Sexta in Quadragésima",
                    desc: "\(fastDesc) Complete abstinence from flesh-meat.",
                    rubric: "℟. Quadragésima · Feria Sexta",
                    strict: true
                )
            }
            // 1917/strict: Saturdays in Lent are days of abstinence (in addition to fast)
            if isSaturday && discipline != .discipline1962 {
                return Penance(
                    title: "Lenten Saturday: Fast & Abstinence",
                    latin: "Sábbato in Quadragésima",
                    desc: "\(fastDesc) Abstinence from flesh-meat (Saturday Lenten abstinence, 1917 Code).",
                    rubric: "℟. Quadragésima · Sábbato",
                    strict: true
                )
            }
            // All other Lenten weekdays: fast
            return Penance(
                title: "Lenten Fast",
                latin: "Ieiúnium Quadragesimále",
                desc: "\(fastDesc) Wednesdays are also days of abstinence.",
                rubric: "℟. \(feriaLatin[dow]) in Quadragésima",
                strict: true
            )
        }

        // Advent
        if season == .advent {
            // Strict: Wednesdays & Fridays are fast + abstinence
            if discipline == .strict && (isWednesday || isFriday) {
                return Penance(
                    title: "Advent Fast & Abstinence",
                    latin: "Ieiúnium et Abstinéntia in Advéntu",
                    desc: "Fast (one full meal, no upper age limit) and abstinence from flesh-meat (pre-1953 Advent discipline).",
                    rubric: "℟. \(feriaLatin[dow]) in Advéntu",
                    strict: true
                )
            }
            // 1917: Advent Fridays & Saturdays are abstinence days
            if discipline == .discipline1917 && (isFriday || isSaturday) {
                return Penance(
                    title: "Advent Abstinence",
                    latin: "Abstinéntia in Advéntu",
                    desc: "Abstain from flesh-meat (Advent Friday/Saturday, 1917 Code).",
                    rubric: "℟. \(feriaLatin[dow]) in Advéntu",
                    strict: false
                )
            }
            // 1962: Advent is penitential but no binding obligation outside Fridays
            if isFriday {
                return Penance(
                    title: "Friday Abstinence",
                    latin: "Feria Sexta",
                    desc: "Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.",
                    rubric: "℟. Feria Sexta",
                    strict: false
                )
            }
            return Penance(
                title: "Advent: Penitential Season",
                latin: "Tempus Advéntus",
                desc: "A penitential season. Offer voluntary fasts and almsgiving as you prepare for the coming of the Lord.",
                rubric: "℟. \(feriaLatin[dow]) in Advéntu",
                strict: false
            )
        }

        // Year-round Friday abstinence (all three disciplines)
        if isFriday {
            return Penance(
                title: "Friday Abstinence",
                latin: "Feria Sexta",
                desc: "Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.",
                rubric: "℟. Feria Sexta",
                strict: false
            )
        }

        // No obligatory penance
        return Penance(
            title: "No obligatory penance",
            latin: "Nulla pænitentia obligatória",
            desc: "A free day. Voluntary mortifications are always meritorious; choose a small sacrifice as your daily offering.",
            rubric: "℟. \(feriaLatin[dow])",
            strict: false
        )
    }

    /// Ember days: Wed/Fri/Sat of the four Ember weeks.
    private static func isEmberDate(date: Date, easter: Date, pentecost: Date,
                                     firstAdvent: Date, cal: Calendar, dow: Int) -> Bool {
        guard dow == 3 || dow == 5 || dow == 6 else { return false }
        let week = cal.component(.weekOfYear, from: date)
        // Advent Ember: 3rd week of Advent
        let adv1Week = cal.component(.weekOfYear, from: firstAdvent)
        if week == adv1Week + 2 { return true }
        // Lent Ember: week of Ash Wednesday (= Easter - 46 days)
        let ashWed = easter.addingDays(-46)
        let ashWeek = cal.component(.weekOfYear, from: ashWed)
        if week == ashWeek { return true }
        // Pentecost Ember: Wed/Fri/Sat within the octave of Pentecost
        // (same week as Pentecost Sunday in a Sunday-start calendar)
        let pentWeek = cal.component(.weekOfYear, from: pentecost)
        if week == pentWeek { return true }
        // September Ember: Wed/Fri/Sat in the week AFTER the week containing
        // Sept 14 (Exaltation of the Cross) — the week of the ordo's
        // "Quattuor Temporum Septembris" days, and the same reckoning the
        // isEmberDay badge uses. (Was +0, which put the 1917-discipline fast
        // dots a week earlier than the calendar's own Ember days.)
        let year = cal.component(.year, from: date)
        var sept14Comps = DateComponents(); sept14Comps.year = year; sept14Comps.month = 9; sept14Comps.day = 14
        if let sept14 = cal.date(from: sept14Comps) {
            let s14week = cal.component(.weekOfYear, from: sept14)
            if week == s14week + 1 { return true }
        }
        return false
    }

    /// Vigil fast days under the 1917 Code: Christmas Eve, Pentecost vigil,
    /// Assumption vigil (Aug 14), All Saints vigil (Oct 31).
    private static func isVigilFast(date: Date, easter: Date, pentecost: Date, cal: Calendar) -> Bool {
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        if m == 12 && d == 24 { return true }    // Christmas Eve
        if m == 8  && d == 14 { return true }    // Assumption Vigil
        if m == 10 && d == 31 { return true }    // All Saints Vigil
        // Pentecost vigil (Saturday before Pentecost)
        if date.isSameDay(as: pentecost.addingDays(-1)) { return true }
        return false
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
                return "Octave of Easter, Day \(daysSinceEaster + 1)"
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

        // Pentecost ember: week after Pentecost
        let pentecostWeek = cal.component(.weekOfYear, from: pentecost)
        if weekOfYear == pentecostWeek { return true }

        // September ember: week containing the Wednesday after Sept 14
        var sept14Comps = DateComponents()
        sept14Comps.year = cal.component(.year, from: date)
        sept14Comps.month = 9; sept14Comps.day = 14
        if let sept14 = cal.date(from: sept14Comps) {
            let sept14Week = cal.component(.weekOfYear, from: sept14)
            if weekOfYear == sept14Week + 1 { return true }
        }

        return false
    }
}
