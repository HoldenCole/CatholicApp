package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.storage.settings.VernacularLanguage
import java.time.LocalDate

// Vernacular-aware calendar names and date strings. English is the
// literal default; Spanish comes from ui_strings_es.json through
// ContentStore.uiString, so the same tables serve every surface that
// prints a weekday, a month, or a short date (Today, Calendar, share
// sheets, widgets).
//
// iOS mirror: Introibo/Liturgical/VernacularDates.swift

object LiturgicalNames {
    val weekdaysEN = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    val weekdayAbbrevsEN = listOf("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")
    val monthsEN = listOf(
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    )
    val monthAbbrevsEN = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

    /** Full weekday name; [dow] is 0 = Sunday … 6 = Saturday. */
    fun weekday(dow: Int): String = ContentStore.uiString("calendar.weekday.$dow", weekdaysEN[dow])

    /** Three-letter weekday abbreviation (upper-case). */
    fun weekdayAbbrev(dow: Int): String = ContentStore.uiString("calendar.weekday_abbrev.$dow", weekdayAbbrevsEN[dow])

    /**
     * Full month name; [month] is 1…12. Spanish months are lower-case (as
     * they run inside a date); [capitalized] lifts the first letter for a
     * heading such as the calendar's month title.
     */
    fun month(month: Int, capitalized: Boolean = false): String {
        val name = ContentStore.uiString("calendar.month.$month", monthsEN[month - 1])
        return if (capitalized) name.replaceFirstChar { it.uppercase() } else name
    }

    /** Short month name; [month] is 1…12. */
    fun monthAbbrev(month: Int): String = ContentStore.uiString("calendar.month_abbrev.$month", monthAbbrevsEN[month - 1])

    /** 0 = Sunday … 6 = Saturday for a java.time date. */
    fun dow(date: LocalDate): Int = date.dayOfWeek.value % 7
}

/**
 * Fixed-shape date strings that follow the vernacular instead of the
 * device locale. Each shape names its English form; the Spanish form
 * puts the day first and joins with "de" where Spanish does.
 */
object VernacularDates {
    private val isSpanish: Boolean get() = ContentStore.currentVernacular == VernacularLanguage.SPANISH

    /** "Sep 8" · "8 sep" */
    fun shortDayMonth(date: LocalDate): String {
        val m = LiturgicalNames.monthAbbrev(date.monthValue)
        return if (isSpanish) "${date.dayOfMonth} $m" else "$m ${date.dayOfMonth}"
    }

    /** "September 8" · "8 de septiembre" */
    fun longDayMonth(date: LocalDate): String {
        val m = LiturgicalNames.month(date.monthValue)
        return if (isSpanish) "${date.dayOfMonth} de $m" else "$m ${date.dayOfMonth}"
    }

    /** "Mon 8 Sep" · "lun 8 sep" */
    fun weekdayDayMonthAbbrev(date: LocalDate): String {
        val wd = LiturgicalNames.weekdayAbbrev(LiturgicalNames.dow(date))
        val cased = if (isSpanish) wd.lowercase() else wd.lowercase().replaceFirstChar { it.uppercase() }
        return "$cased ${date.dayOfMonth} ${LiturgicalNames.monthAbbrev(date.monthValue)}"
    }

    /** "Monday, September 8" · "lunes, 8 de septiembre" */
    fun weekdayLongDate(date: LocalDate): String {
        val wd = LiturgicalNames.weekday(LiturgicalNames.dow(date))
        val m = LiturgicalNames.month(date.monthValue)
        return if (isSpanish) "${wd.lowercase()}, ${date.dayOfMonth} de $m" else "$wd, $m ${date.dayOfMonth}"
    }

    /** "Monday 8 September" · "lunes 8 de septiembre" */
    fun weekdayDayMonth(date: LocalDate): String {
        val wd = LiturgicalNames.weekday(LiturgicalNames.dow(date))
        val m = LiturgicalNames.month(date.monthValue)
        return if (isSpanish) "${wd.lowercase()} ${date.dayOfMonth} de $m" else "$wd ${date.dayOfMonth} $m"
    }

    /** "September 2026" · "Septiembre 2026" */
    fun monthYear(date: LocalDate): String =
        "${LiturgicalNames.month(date.monthValue, capitalized = true)} ${date.year}"

    /** "September" · "Septiembre" */
    fun monthName(date: LocalDate): String = LiturgicalNames.month(date.monthValue, capitalized = true)
}
