package com.lampstandhq.introibo.data.liturgical

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum class LiturgicalSeason(val key: String) {
    ADVENT("advent"),
    CHRISTMAS("christmas"),
    LENT("lent"),
    PASSION("passion"),
    PENTECOST("pentecost"),
    EASTER("easter"),
    PER_ANNUM("perAnnum"),
}

enum class LiturgicalColour(val key: String) {
    VIOLET("violet"),
    ROSE("rose"),
    WHITE("white"),
    RED("red"),
    GREEN("green"),
}

enum class MysterySet(val key: String) {
    JOYFUL("joyful"),
    SORROWFUL("sorrowful"),
    GLORIOUS("glorious");

    val latinName: String
        get() = when (this) {
            JOYFUL -> "Mystéria Gaudiósa"
            SORROWFUL -> "Mystéria Dolorósa"
            GLORIOUS -> "Mystéria Gloriósa"
        }

    val englishName: String
        get() = when (this) {
            JOYFUL -> "Joyful Mysteries"
            SORROWFUL -> "Sorrowful Mysteries"
            GLORIOUS -> "Glorious Mysteries"
        }
}

enum class MarianAntiphon(val key: String) {
    ALMA("alma"),
    AVE("ave"),
    REGINA("regina"),
    SALVE("salve");

    val title: String
        get() = when (this) {
            ALMA -> "Alma Redemptóris Mater"
            AVE -> "Ave Regína Cælórum"
            REGINA -> "Regína Cæli"
            SALVE -> "Salve Regína"
        }
}

data class Penance(
    val title: String,
    val latin: String,
    val desc: String,
    val rubric: String,
    val strict: Boolean,
)

// ---------------------------------------------------------------------------
// LiturgicalContext
// ---------------------------------------------------------------------------

data class LiturgicalContext(
    val date: LocalDate,
    val season: LiturgicalSeason,
    val colour: LiturgicalColour,
    val latinName: String,
    val englishName: String,
    val feriaLatin: String,
    val feriaEnglish: String,
    val dayOfWeek: Int,       // 0 = Sunday ... 6 = Saturday
    val isSunday: Boolean,
    val isFriday: Boolean,
    val isLent: Boolean,
    val marian: MarianAntiphon,
    val mystery: MysterySet,
    val penance: Penance,

    val properSlug: String?,
    val temporalKey: String? = null,

    // Key dates of the liturgical year
    val easter: LocalDate,
    val ashWednesday: LocalDate,
    val pentecost: LocalDate,
    val trinitySunday: LocalDate,
    val firstAdvent: LocalDate,
) {
    companion object {

        fun current(): LiturgicalContext = forDate(LocalDate.now())

        /**
         * Build the full liturgical context for [now].
         * Direct port of LiturgicalContext.for(date:) in the iOS codebase.
         */
        fun forDate(now: LocalDate): LiturgicalContext {
            val year = now.year

            // Feast anchors
            val easter = Computus.easterSunday(year)
            val ashWed = easter.addDays(-46)
            val passionStart = easter.addDays(-14)   // Passion Sunday
            val holyWed = easter.addDays(-4)
            val pentecost = easter.addDays(49)
            val trinity = easter.addDays(56)
            val firstAdvent = Computus.firstSundayOfAdvent(year)
            val christmas = LocalDate.of(year, 12, 25)
            val candlemas = LocalDate.of(year, 2, 2)

            // ---- Season detection ----
            val season: LiturgicalSeason
            val colour: LiturgicalColour
            val latinName: String
            val englishName: String

            if (now.isSameOrAfter(firstAdvent) && now.isSameOrBefore(christmas.addDays(-1))) {
                season = LiturgicalSeason.ADVENT
                colour = LiturgicalColour.VIOLET
                latinName = "Tempus Advéntus"
                englishName = "Advent"
            } else if (now.isSameOrAfter(christmas) || now.isSameOrBefore(candlemas.addDays(-1))) {
                season = LiturgicalSeason.CHRISTMAS
                colour = LiturgicalColour.WHITE
                latinName = "Tempus Nativitátis"
                englishName = "Christmastide"
            } else if (now.isSameOrAfter(ashWed) && now.isSameOrBefore(easter.addDays(-1))) {
                if (now.isSameOrAfter(passionStart)) {
                    season = LiturgicalSeason.PASSION
                    colour = LiturgicalColour.VIOLET
                    latinName = "Tempus Passiónis"
                    englishName = "Passiontide"
                } else {
                    season = LiturgicalSeason.LENT
                    colour = LiturgicalColour.VIOLET
                    latinName = "Quadragésima"
                    englishName = "Lent"
                }
            } else if (now.isSameDay(pentecost)) {
                season = LiturgicalSeason.PENTECOST
                colour = LiturgicalColour.RED
                latinName = "Pentecóste"
                englishName = "Pentecost"
            } else if (now.isSameOrAfter(easter) && now.isSameOrBefore(trinity.addDays(-1))) {
                season = LiturgicalSeason.EASTER
                colour = LiturgicalColour.WHITE
                latinName = "Tempus Paschále"
                englishName = "Eastertide"
            } else if (now.isSameOrAfter(trinity)) {
                season = LiturgicalSeason.PER_ANNUM
                colour = LiturgicalColour.GREEN
                latinName = "Tempus post Pentecósten"
                englishName = "Time after Pentecost"
            } else {
                season = LiturgicalSeason.PER_ANNUM
                colour = LiturgicalColour.GREEN
                latinName = "Tempus post Epiphaníam"
                englishName = "Time after Epiphany"
            }

            // ---- Day-of-week ----
            // java.time DayOfWeek: MONDAY=1 ... SUNDAY=7
            // Convert to 0=Sun..6=Sat to match the iOS calendar convention.
            val dow = dayOfWeekIndex(now)
            val isSunday = dow == 0
            val isFriday = dow == 5
            val isLent = (season == LiturgicalSeason.LENT || season == LiturgicalSeason.PASSION)

            // ---- Marian antiphon ----
            val marian: MarianAntiphon = if (now.isSameOrAfter(firstAdvent) || now.isSameOrBefore(candlemas.addDays(-1))) {
                MarianAntiphon.ALMA
            } else if (now.isSameOrAfter(candlemas) && now.isSameOrBefore(holyWed)) {
                MarianAntiphon.AVE
            } else if (now.isSameOrAfter(easter) && now.isSameOrBefore(trinity.addDays(-1))) {
                MarianAntiphon.REGINA
            } else {
                MarianAntiphon.SALVE
            }

            // ---- Rosary mystery for today ----
            // Traditional schedule (no Luminous):
            //   Sun/Wed/Sat: Glorious   Mon/Thu: Joyful   Tue/Fri: Sorrowful
            // With seasonal overrides on Sunday:
            //   Advent Sunday    -> Joyful
            //   Lent/Passion Sun -> Sorrowful
            val byDow = listOf(
                MysterySet.GLORIOUS, MysterySet.JOYFUL, MysterySet.SORROWFUL,
                MysterySet.GLORIOUS, MysterySet.JOYFUL, MysterySet.SORROWFUL,
                MysterySet.GLORIOUS,
            )
            var mystery = byDow[dow]
            if (isSunday && season == LiturgicalSeason.ADVENT) mystery = MysterySet.JOYFUL
            if (isSunday && isLent) mystery = MysterySet.SORROWFUL

            // ---- Penance (1962 norms) ----
            val penance: Penance = if (isLent && isFriday) {
                Penance(
                    title = "Lenten Friday",
                    latin = "Feria Sexta in Quadragésima",
                    desc = "Abstinence from flesh-meat. Those of fasting age observe the Lenten fast: one full meal and two small collations.",
                    rubric = "℟. Quadragésima · Feria Sexta",
                    strict = true,
                )
            } else if (isLent) {
                Penance(
                    title = "Lenten Fast",
                    latin = "Ieiúnium Quadragesimále",
                    desc = "Those of fasting age (21-59) observe the Lenten fast: one full meal and two small collations. Wednesdays in Lent are also days of abstinence.",
                    rubric = "℟. ${feriaLatinNames[dow]} in Quadragésima",
                    strict = true,
                )
            } else if (isFriday) {
                Penance(
                    title = "Friday Abstinence",
                    latin = "Feria Sexta",
                    desc = "Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.",
                    rubric = "℟. Feria Sexta",
                    strict = false,
                )
            } else if (season == LiturgicalSeason.ADVENT && (dow == 3 || dow == 5 || dow == 6)) {
                Penance(
                    title = "Advent Penance",
                    latin = "Tempus Advéntus",
                    desc = "A penitential season. Offer voluntary fasts and almsgiving as you prepare for the coming of the Lord.",
                    rubric = "℟. ${feriaLatinNames[dow]} in Advéntu",
                    strict = false,
                )
            } else if (isSunday) {
                Penance(
                    title = "Day of the Lord",
                    latin = "Dies Domínica",
                    desc = "No obligation of fasting or abstinence. Rest in the Lord and attend Holy Mass.",
                    rubric = "℟. Domínica",
                    strict = false,
                )
            } else {
                Penance(
                    title = "No obligatory penance",
                    latin = "Nulla pæniténtia obligatória",
                    desc = "A free day. Voluntary mortifications are always meritorious, choose a small sacrifice as your daily offering.",
                    rubric = "℟. ${feriaLatinNames[dow]}",
                    strict = false,
                )
            }

            val temporal = computeTemporalKey(
                now, easter, ashWed, pentecost, trinity, firstAdvent, christmas, season, dow,
            )

            return LiturgicalContext(
                date = now,
                season = season,
                colour = colour,
                latinName = latinName,
                englishName = englishName,
                feriaLatin = feriaLatinNames[dow],
                feriaEnglish = feriaEnglishNames[dow],
                dayOfWeek = dow,
                isSunday = isSunday,
                isFriday = isFriday,
                isLent = isLent,
                marian = marian,
                mystery = mystery,
                penance = penance,
                properSlug = ProperCalendar.properSlug(now),
                temporalKey = temporal,
                easter = easter,
                ashWednesday = ashWed,
                pentecost = pentecost,
                trinitySunday = trinity,
                firstAdvent = firstAdvent,
            )
        }

        private fun computeTemporalKey(
            date: LocalDate, easter: LocalDate, ashWed: LocalDate,
            pentecost: LocalDate, trinity: LocalDate,
            firstAdvent: LocalDate, christmas: LocalDate,
            season: LiturgicalSeason, dow: Int,
        ): String? {
            val septuagesima = ashWed.minusDays(17)

            // Easter season
            if (date >= easter && date < pentecost.plusDays(7)) {
                val days = ChronoUnit.DAYS.between(easter, date).toInt()
                return "pasc${days / 7}-${days % 7}"
            }

            // Lent: Quad1-0 = 1st Sunday of Lent
            val firstSunLent = ashWed.plusDays(4) // Ash Wed is always Wednesday
            if (date >= firstSunLent && date < easter) {
                val days = ChronoUnit.DAYS.between(firstSunLent, date).toInt()
                return "quad${days / 7 + 1}-${days % 7}"
            }

            // Pre-Lent (Septuagesima through Sat before 1st Lent Sunday)
            if (date >= septuagesima && date < firstSunLent) {
                val days = ChronoUnit.DAYS.between(septuagesima, date).toInt()
                return "quadp${days / 7 + 1}-${days % 7}"
            }

            // Advent
            if (date >= firstAdvent && date < christmas) {
                val days = ChronoUnit.DAYS.between(firstAdvent, date).toInt()
                return "adv${days / 7 + 1}-${days % 7}"
            }

            // After Pentecost
            if (date >= trinity && date < firstAdvent) {
                val days = ChronoUnit.DAYS.between(trinity, date).toInt()
                return "pent%02d-%d".format(days / 7 + 1, days % 7)
            }

            // After Epiphany
            val epiphany = LocalDate.of(date.year, 1, 6)
            var epi1Sun = epiphany
            while (epi1Sun.dayOfWeek != java.time.DayOfWeek.SUNDAY) epi1Sun = epi1Sun.plusDays(1)
            if (date >= epi1Sun && date < septuagesima) {
                val days = ChronoUnit.DAYS.between(epi1Sun, date).toInt()
                return "epi${days / 7 + 1}-${days % 7}"
            }

            return null
        }

        // ---- Static lookup tables ----

        private val feriaLatinNames = listOf(
            "Domínica", "Feria Secúnda", "Feria Tértia", "Feria Quarta",
            "Feria Quinta", "Feria Sexta", "Sábbato",
        )
        private val feriaEnglishNames = listOf(
            "Sunday", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday",
        )

        /**
         * Convert [java.time.DayOfWeek] to 0=Sun..6=Sat (matching iOS convention).
         */
        fun dayOfWeekIndex(date: LocalDate): Int {
            // DayOfWeek.MONDAY.value == 1, SUNDAY.value == 7
            return date.dayOfWeek.value % 7  // SUNDAY(7) -> 0, MONDAY(1) -> 1, ... SATURDAY(6) -> 6
        }
    }
}

// ---------------------------------------------------------------------------
// Extensions -- seasonal notes, first-Friday/Saturday, Ember days
// ---------------------------------------------------------------------------

/** Seasonal countdown or contextual note for the Today screen. */
val LiturgicalContext.seasonalNote: String?
    get() {
        // Lent/Passion countdown to Easter
        if (season == LiturgicalSeason.LENT || season == LiturgicalSeason.PASSION) {
            val days = ChronoUnit.DAYS.between(date, easter).toInt()
            if (days == 0) return null
            val plural = if (days == 1) "" else "s"
            return "$days day$plural until Easter Sunday"
        }

        // Advent countdown to Christmas
        if (season == LiturgicalSeason.ADVENT) {
            val christmas = LocalDate.of(date.year, 12, 25)
            val days = ChronoUnit.DAYS.between(date, christmas).toInt()
            if (days == 0) return "Christmas Day"
            val plural = if (days == 1) "" else "s"
            return "$days day$plural until Christmas"
        }

        // Easter octave
        if (season == LiturgicalSeason.EASTER) {
            val daysSinceEaster = ChronoUnit.DAYS.between(easter, date).toInt()
            if (daysSinceEaster in 0..7) {
                return "Octave of Easter, Day ${daysSinceEaster + 1}"
            }
            val daysToPentecost = ChronoUnit.DAYS.between(date, pentecost).toInt()
            if (daysToPentecost in 1..10) {
                val plural = if (daysToPentecost == 1) "" else "s"
                return "$daysToPentecost day$plural until Pentecost"
            }
        }

        return null
    }

val LiturgicalContext.isFirstFriday: Boolean
    get() {
        if (date.dayOfWeek != DayOfWeek.FRIDAY) return false
        return date.dayOfMonth <= 7
    }

val LiturgicalContext.isFirstSaturday: Boolean
    get() {
        if (date.dayOfWeek != DayOfWeek.SATURDAY) return false
        return date.dayOfMonth <= 7
    }

val LiturgicalContext.isEmberDay: Boolean
    get() {
        // Ember days fall on Wed/Fri/Sat of the Ember weeks
        val dow = dayOfWeek
        if (dow != 3 && dow != 5 && dow != 6) return false

        // We compare by computing week-of-year using ISO fields, matching the
        // iOS Calendar.weekOfYear behavior closely enough for these checks.
        val dateWeek = weekOfYear(date)

        // Advent ember: 3rd week of Advent
        if (season == LiturgicalSeason.ADVENT) {
            val advent1Week = weekOfYear(firstAdvent)
            if (dateWeek == advent1Week + 2) return true
        }

        // Lent ember: week after Ash Wednesday
        if (season == LiturgicalSeason.LENT) {
            val ashWeek = weekOfYear(ashWednesday)
            if (dateWeek == ashWeek) return true
        }

        return false
    }

private fun weekOfYear(date: LocalDate): Int =
    date.get(java.time.temporal.WeekFields.SUNDAY_START.weekOfYear())

// ---------------------------------------------------------------------------
// LongDateFormatter
// ---------------------------------------------------------------------------

object LongDateFormatter {
    private val ordinals = listOf(
        "", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
        "tenth", "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth",
        "seventeenth", "eighteenth", "nineteenth", "twentieth", "twenty-first", "twenty-second",
        "twenty-third", "twenty-fourth", "twenty-fifth", "twenty-sixth", "twenty-seventh",
        "twenty-eighth", "twenty-ninth", "thirtieth", "thirty-first",
    )

    private val months = listOf(
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    )

    fun format(date: LocalDate): String {
        val day = date.dayOfMonth
        val month = date.monthValue
        return "the ${ordinals[day]} of ${months[month - 1]}"
    }
}
