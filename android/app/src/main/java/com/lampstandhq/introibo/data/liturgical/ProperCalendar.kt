package com.lampstandhq.introibo.data.liturgical

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Determines the proper-of-the-day slug for a given date.
 * Direct port of Introibo/Liturgical/ProperCalendar.swift.
 */
object ProperCalendar {

    fun properSlug(date: LocalDate, propers: List<String> = emptyList()): String? {
        val year = date.year
        val easter = Computus.easterSunday(year)
        val dow = LiturgicalContext.dayOfWeekIndex(date) // 0=Sun..6=Sat

        // High-priority moveable feasts override everything
        moveableSlug(date, easter)?.let { return it }

        // Fixed sanctorale feasts (high-rank saints in fixedFeasts dictionary)
        fixedFeastSlug(date)?.let { return it }

        // On Sundays, the temporal cycle takes precedence over generic saints
        if (dow == 0) {
            temporaleSlug(date, easter, year)?.let { return it }
        }

        // On weekdays, check if a saint's feast proper exists for this date
        val month = date.monthValue
        val day = date.dayOfMonth
        val sanctiSlug = String.format("sancti-%02d-%02d", month, day)
        if (propers.contains(sanctiSlug)) {
            return sanctiSlug
        }

        // Temporal cycle for weekdays without a saint's feast
        temporaleSlug(date, easter, year)?.let { slug ->
            if (isSaturdayBVMEligible(date, slug)) {
                return "saturday-bvm"
            }
            return slug
        }

        // Final fallback
        return sanctiSlug
    }

    private fun isSaturdayBVMEligible(date: LocalDate, slug: String): Boolean {
        val dow = LiturgicalContext.dayOfWeekIndex(date)
        if (dow != 6) return false
        return slug.matches(Regex("^(pentecost|epiphany)-\\d+-6$"))
    }

    fun properSlugWithFallback(date: LocalDate, store: List<String>): String? {
        val slug = properSlug(date)
        if (slug != null && store.contains(slug)) {
            return slug
        }
        val dow = LiturgicalContext.dayOfWeekIndex(date) // 0=Sun..6=Sat
        if (dow > 0) {
            val lastSunday = date.addDays(-dow)
            val sundaySlug = properSlug(lastSunday)
            if (sundaySlug != null && store.contains(sundaySlug)) {
                return sundaySlug
            }
        }
        return properSlug(date)
    }

    // ---- Moveable feasts that take precedence over fixed sanctorale ----

    private fun moveableSlug(date: LocalDate, easter: LocalDate): String? {
        val diff = ChronoUnit.DAYS.between(easter, date).toInt()
        return when (diff) {
            38 -> "vigil-ascension"
            39 -> "ascension"
            48 -> "vigil-pentecost"
            49 -> "pentecost-sunday"
            60 -> "corpus-christi"
            68 -> "sacred-heart"
            else -> null
        }
    }

    // ---- Temporale (moveable cycle) ----

    private fun temporaleSlug(date: LocalDate, easter: LocalDate, year: Int): String? {
        val diff = ChronoUnit.DAYS.between(easter, date).toInt()
        val dow = LiturgicalContext.dayOfWeekIndex(date) // 0=Sun..6=Sat
        val firstAdvent = Computus.firstSundayOfAdvent(year)

        // Easter Octave (week 0): Easter Sunday through Saturday
        if (diff in 0..6) {
            if (diff == 0) return "easter-sunday"
            return "easter-0-$diff"
        }

        // Easter weeks 1-7 (Low Sunday through Pentecost vigil)
        if (diff in 7..48) {
            val week = diff / 7
            val dayInWeek = diff % 7
            if (dayInWeek == 0) return "easter-$week"
            return "easter-$week-$dayInWeek"
        }

        // Pentecost Sunday + Octave
        if (diff == 49) return "easter-7"
        if (diff in 50..55) {
            return "easter-7-${diff - 49}"
        }

        // Trinity Sunday
        if (diff == 56) return "trinity-sunday"

        // Sundays + weekdays after Pentecost
        val trinity = easter.addDays(56)
        if (date.isSameOrAfter(trinity) && date.isSameOrBefore(firstAdvent.addDays(-1))) {
            val daysAfterTrinity = ChronoUnit.DAYS.between(trinity, date).toInt()
            val week = daysAfterTrinity / 7 + 1
            val dayInWeek = daysAfterTrinity % 7
            if (week in 1..24) {
                if (dayInWeek == 0) return "pentecost-$week"
                return "pentecost-$week-$dayInWeek"
            }
        }

        // Pre-Lent
        if (diff in -63..-50) {
            val prelentDay = diff + 63
            val week = prelentDay / 7 + 1  // 1=Sept, 2=Sexag, 3=Quinq
            val dayInWeek = prelentDay % 7
            val names = mapOf(1 to "septuagesima", 2 to "sexagesima", 3 to "quinquagesima")
            val name = names[week]
            if (name != null) {
                if (dayInWeek == 0) return name
                return "$name-$dayInWeek"
            }
        }

        // Ash Wednesday through Lent
        if (diff == -46) return "quinquagesima-3"  // Ash Wednesday
        if (diff in -45..-43) {
            return "quinquagesima-${diff + 49}"
        }

        // Lent weeks 1-4
        if (diff in -42..-15) {
            val lentDay = diff + 42
            val week = lentDay / 7 + 1
            val dayInWeek = lentDay % 7
            if (week in 1..4) {
                if (dayInWeek == 0) return "lent-$week"
                return "lent-$week-$dayInWeek"
            }
        }

        // Passion week (week 5)
        if (diff in -14..-8) {
            val dayInWeek = diff + 14
            if (dayInWeek == 0) return "passion-sunday"
            return "lent-5-$dayInWeek"
        }

        // Holy Week
        if (diff in -7..-1) {
            val dayInWeek = diff + 7
            if (dayInWeek == 0) return "palm-sunday"
            val names = mapOf(
                1 to "holy-week-1", 2 to "holy-week-2", 3 to "holy-week-3",
                4 to "holy-thursday", 5 to "good-friday", 6 to "holy-saturday",
            )
            return names[dayInWeek]
        }

        // Epiphany season
        val epiphany = LocalDate.of(year, 1, 6)
        val septuagesima = easter.addDays(-63)
        if (date.isSameOrAfter(epiphany) && date.isSameOrBefore(septuagesima.addDays(-1))) {
            val daysAfterEpiph = ChronoUnit.DAYS.between(epiphany, date).toInt()
            if (daysAfterEpiph > 0) {
                // Find which Sunday week we're in
                val nextSunday = daysAfterEpiph + (7 - ((daysAfterEpiph - 1) % 7 + 1)) % 7
                val week = nextSunday / 7
                if (week in 1..6) {
                    if (dow == 0) return "epiphany-$week"
                    return "epiphany-$week-$dow"
                }
            }
        }

        // Advent
        if (date.isSameOrAfter(firstAdvent)) {
            val daysInAdvent = ChronoUnit.DAYS.between(firstAdvent, date).toInt()
            val week = daysInAdvent / 7 + 1
            val dayInWeek = daysInAdvent % 7
            if (week in 1..4) {
                if (dayInWeek == 0) return "advent-$week"
                return "advent-$week-$dayInWeek"
            }
        }

        return null
    }

    // ---- Sanctorale (fixed cycle) ----

    private fun fixedFeastSlug(date: LocalDate): String? {
        val month = date.monthValue
        val day = date.dayOfMonth
        val dow = date.dayOfWeek.value % 7 // 0=Sun..6=Sat

        // Christ the King: last Sunday of October
        if (month == 10 && dow == 0 && day >= 25) return "christ-king"

        // Sundays after Christmas
        if (month == 12 && day >= 26 && dow == 0) return "christmas-1"
        if (month == 1 && day in 2..5 && dow == 0) return "christmas-2"

        val key = month * 100 + day
        return fixedFeasts[key]
    }

    private val fixedFeasts: Map<Int, String> = mapOf(
        101 to "circumcision",
        106 to "epiphany",
        202 to "purification",
        319 to "st-joseph",
        325 to "annunciation",
        501 to "st-joseph-worker",
        624 to "nativity-john-baptist",
        629 to "sts-peter-paul",
        815 to "assumption",
        908 to "nativity-bvm",
        1001 to "holy-rosary",
        1101 to "all-saints",
        1102 to "all-souls",
        1208 to "immaculate-conception",
        1225 to "christmas",
        1226 to "st-stephen",
        1227 to "st-john-evangelist",
        1228 to "holy-innocents",
    )
}
