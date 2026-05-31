package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.storage.settings.PenanceDiscipline
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
    BLACK("black");

    companion object {
        /**
         * Resolves an ordo `color` string (as stored in ordo.json) to a colour.
         * Unknown strings fall back to [GREEN] (ferial per annum), mirroring the
         * iOS `LiturgicalColour.from(ordoColor:)` so calendar cells never crash
         * on an unexpected value.
         */
        fun from(key: String): LiturgicalColour =
            entries.firstOrNull { it.key == key } ?: GREEN
    }
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
    SALVE("salve"),
    SUPPRESSED("suppressed");

    val title: String
        get() = when (this) {
            ALMA -> "Alma Redemptóris Mater"
            AVE -> "Ave Regína Cælórum"
            REGINA -> "Regína Cæli"
            SALVE -> "Salve Regína"
            SUPPRESSED -> ""
        }

    /** Whether the antiphon is suppressed (Triduum — no Marian antiphon at Compline). */
    val isSuppressed: Boolean get() = this == SUPPRESSED
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
        fun forDate(
            now: LocalDate,
            discipline: PenanceDiscipline = PenanceDiscipline.DISCIPLINE_1962,
        ): LiturgicalContext {
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
            // Boundary rules (Breviary of Pius V, 1569; 1962 rubrics):
            //  - Alma: from First Vespers of Advent I (= Saturday before Advent I)
            //    through Compline of Feb 1. Feb 2 (Candlemas) belongs to Ave.
            //  - Ave: from Compline of Feb 2 through Compline of Holy Wednesday.
            //  - Triduum (Maundy Thu / Good Fri / Holy Sat): no Marian antiphon
            //    is said at Compline (suppressed).
            //  - Regina Caeli: Easter Sunday through the day before Trinity Sunday.
            //  - Salve: Trinity Sunday through Friday before Advent I.
            val triduumStart = easter.addDays(-3)    // Maundy Thursday
            val triduumEnd = easter.addDays(-1)      // Holy Saturday
            val almaStart = firstAdvent.addDays(-1)  // Saturday before Advent I (First Vespers)
            val marian: MarianAntiphon = if (now.isSameOrAfter(triduumStart) && now.isSameOrBefore(triduumEnd)) {
                MarianAntiphon.SUPPRESSED   // Triduum: no Marian antiphon at Compline
            } else if (now.isSameOrAfter(almaStart) || now.isSameOrBefore(candlemas.addDays(-1))) {
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

            // ---- Penance (discipline-aware) ----
            val penance = computePenance(
                discipline, season, dow, isSunday, isFriday, isLent,
                now, easter, pentecost, firstAdvent,
            )

            val temporal = computeTemporalKey(
                now, easter, ashWed, pentecost, trinity, firstAdvent, christmas,
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

            // Christmas to Epiphany
            if (date >= christmas || date < epi1Sun) {
                if (date >= christmas) {
                    val days = ChronoUnit.DAYS.between(christmas, date).toInt()
                    return "nat$days"
                }
            }

            return null
        }

        // ---- Discipline-aware penance ----

        internal fun computePenance(
            discipline: PenanceDiscipline,
            season: LiturgicalSeason, dow: Int,
            isSunday: Boolean, isFriday: Boolean, isLent: Boolean,
            date: LocalDate, easter: LocalDate, pentecost: LocalDate,
            firstAdvent: LocalDate,
        ): Penance {
            val isSaturday = dow == 6
            val isWednesday = dow == 3
            if (isSunday) return Penance("Day of the Lord", "Dies Domínica",
                "No obligation of fasting or abstinence. Rest in the Lord and attend Holy Mass.",
                "℟. Domínica", false)

            if (discipline != PenanceDiscipline.DISCIPLINE_1962 &&
                isEmberDate(date, easter, pentecost, firstAdvent, dow)) {
                val desc = if (discipline == PenanceDiscipline.STRICT)
                    "Fast (one full meal, no upper age limit) and complete abstinence from flesh-meat."
                else "Fast (one full meal and two collations, ages 21–59) and abstinence from flesh-meat."
                return Penance("Ember Day: Fast & Abstinence", "Quattuor Témporum", desc,
                    "℟. Quattuor Témporum", true)
            }
            if (discipline != PenanceDiscipline.DISCIPLINE_1962 &&
                isVigilFast(date, pentecost)) {
                val desc = if (discipline == PenanceDiscipline.STRICT)
                    "Fast (one full meal, no upper age limit) and abstinence."
                else "Fast (one full meal and two collations, ages 21–59) and abstinence."
                return Penance("Vigil: Fast & Abstinence", "Vigília: Ieiúnium", desc,
                    "℟. Vigília", true)
            }
            if (isLent) {
                val fastDesc = if (discipline == PenanceDiscipline.STRICT)
                    "Fast: one full meal (no upper age limit). Two small collations permitted."
                else "Fast: one full meal and two small collations (ages 21–59)."
                if (isFriday) return Penance("Lenten Friday: Fast & Abstinence",
                    "Feria Sexta in Quadragésima",
                    "$fastDesc Complete abstinence from flesh-meat.",
                    "℟. Quadragésima · Feria Sexta", true)
                if (isSaturday && discipline != PenanceDiscipline.DISCIPLINE_1962)
                    return Penance("Lenten Saturday: Fast & Abstinence",
                        "Sábbato in Quadragésima",
                        "$fastDesc Abstinence from flesh-meat (Saturday Lenten abstinence, 1917 Code).",
                        "℟. Quadragésima · Sábbato", true)
                return Penance("Lenten Fast", "Ieiúnium Quadragesimále",
                    "$fastDesc Wednesdays are also days of abstinence.",
                    "℟. ${feriaLatinNames[dow]} in Quadragésima", true)
            }
            if (season == LiturgicalSeason.ADVENT) {
                if (discipline == PenanceDiscipline.STRICT && (isWednesday || isFriday))
                    return Penance("Advent Fast & Abstinence", "Ieiúnium et Abstinéntia in Advéntu",
                        "Fast (one full meal, no upper age limit) and abstinence from flesh-meat (pre-1953 Advent discipline).",
                        "℟. ${feriaLatinNames[dow]} in Advéntu", true)
                if (discipline == PenanceDiscipline.DISCIPLINE_1917 && (isFriday || isSaturday))
                    return Penance("Advent Abstinence", "Abstinéntia in Advéntu",
                        "Abstain from flesh-meat (Advent Friday/Saturday, 1917 Code).",
                        "℟. ${feriaLatinNames[dow]} in Advéntu", false)
                if (isFriday) return Penance("Friday Abstinence", "Feria Sexta",
                    "Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.",
                    "℟. Feria Sexta", false)
                return Penance("Advent: Penitential Season", "Tempus Advéntus",
                    "A penitential season. Offer voluntary fasts and almsgiving as you prepare for the coming of the Lord.",
                    "℟. ${feriaLatinNames[dow]} in Advéntu", false)
            }
            if (isFriday) return Penance("Friday Abstinence", "Feria Sexta",
                "Abstain from the flesh of warm-blooded animals, in memory of the Passion of Our Lord.",
                "℟. Feria Sexta", false)
            return Penance("No obligatory penance", "Nulla pæniténtia obligatória",
                "A free day. Voluntary mortifications are always meritorious; choose a small sacrifice as your daily offering.",
                "℟. ${feriaLatinNames[dow]}", false)
        }

        private fun isEmberDate(date: LocalDate, easter: LocalDate, pentecost: LocalDate,
                                firstAdvent: LocalDate, dow: Int): Boolean {
            if (dow != 3 && dow != 5 && dow != 6) return false
            val woy = date.get(java.time.temporal.IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            val adv1w = firstAdvent.get(java.time.temporal.IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            if (woy == adv1w + 2) return true
            val ashWed = easter.minusDays(46)
            val ashw = ashWed.get(java.time.temporal.IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            if (woy == ashw) return true
            // ISO weeks are Monday-start: Pentecost (Sunday) is in ISO week N,
            // but the Ember Wed/Fri/Sat of the octave are in ISO week N+1.
            val pentw = pentecost.get(java.time.temporal.IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            if (woy == pentw + 1) return true
            val sept14 = LocalDate.of(date.year, 9, 14)
            val septw = sept14.get(java.time.temporal.IsoFields.WEEK_OF_WEEK_BASED_YEAR)
            if (woy == septw) return true
            return false
        }

        private fun isVigilFast(date: LocalDate, pentecost: LocalDate): Boolean {
            val m = date.monthValue; val d = date.dayOfMonth
            if (m == 12 && d == 24) return true
            if (m == 8 && d == 14) return true
            if (m == 10 && d == 31) return true
            if (date == pentecost.minusDays(1)) return true
            return false
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

/**
 * Recompute the penance for this context under a specific [discipline].
 * Used by the Today screen when the user's discipline differs from the default
 * baked into [LiturgicalContext.penance] at construction time.
 */
fun LiturgicalContext.penanceFor(discipline: PenanceDiscipline): Penance =
    LiturgicalContext.computePenance(
        discipline, season, dayOfWeek, isSunday, isFriday, isLent,
        date, easter, pentecost, firstAdvent,
    )

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
