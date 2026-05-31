package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.OrdoEntry
import com.lampstandhq.introibo.storage.settings.MissalRite
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

// MARK: - LiturgicalCalendar (month-grid model)
//
// Pure, side-effect-free model for the browsable liturgical calendar. Given a
// (year, month, rite) it produces the Sunday-first grid the UI lays out: the
// number of leading blank cells, then one [CalendarDay] per day-of-month, each
// carrying its resolved ordo entry. All liturgical knowledge is delegated to
// ContentStore.ordoForDate -- this file only does calendar geometry.
//
// iOS mirror:
//   Introibo/Liturgical/LiturgicalCalendar.swift
// Both platforms read the SAME bundled ordo tables, so a given (year, month,
// rite) yields the same feast/colour per day on each platform by construction.

/** One day cell in a calendar list row. */
data class CalendarDay(
    val date: LocalDate,
    val day: Int,            // day-of-month, 1..31
    val weekday: Int,        // 1=Sun .. 7=Sat (matches iOS Calendar.liturgical weekday)
    val ordo: OrdoEntry?,    // null only if the date is outside the bundled ordo
    val englishName: String?, // full English translation of ordo.name, if bundled
    val isToday: Boolean,
) {
    /** Display colour for the cell's pip; null when there is no ordo entry. */
    val colour: LiturgicalColour?
        get() = ordo?.let { LiturgicalColour.from(it.color) }

    /** Short feast/feria label for the cell (full ordo name; the view truncates). */
    val label: String?
        get() = ordo?.name

    /** A 1st- or 2nd-class day (rank >= 5) — the view emphasises these. */
    val isMajor: Boolean
        get() = (ordo?.rank ?: 0.0) >= 5.0

    val isSunday: Boolean get() = weekday == 1

    /** Three-letter weekday abbreviation. */
    val weekdayAbbrev: String get() = abbrevs[weekday - 1]

    /** Full English weekday name. */
    val weekdayName: String get() = dayNames[weekday - 1]

    /**
     * The English line shown beneath the Latin name — the full feast/feria
     * translation when bundled, else just the weekday.
     */
    val englishLine: String get() = englishName ?: weekdayName

    /** English season label (for the inline season dividers). */
    val seasonLabel: String? get() = ordo?.season?.let { seasonLabels[it] }

    companion object {
        private val abbrevs = listOf("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")
        private val dayNames = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
        private val seasonLabels = mapOf(
            "advent" to "Advent",
            "christmas" to "Christmastide",
            "lent" to "Lent",
            "easter" to "Eastertide",
            "ordinary" to "Ordinary Time",
            "pre-lent" to "Pre-Lent",
        )
    }
}

/** A single month laid out for display. */
data class CalendarMonth(
    val year: Int,
    val month: Int,          // 1..12
    val title: String,       // "May 2026"
    val leadingBlanks: Int,  // empty cells before day 1 (Sunday-first week)
    val days: List<CalendarDay>,
) {
    companion object {
        private val titleFormatter: DateTimeFormatter =
            DateTimeFormatter.ofPattern("LLLL yyyy", Locale.US)

        /**
         * Builds the grid for [year]/[month] under [rite]. [today] is injectable
         * for testing; defaults to now. [month] is 1-based.
         */
        fun build(
            year: Int,
            month: Int,
            rite: MissalRite,
            today: LocalDate = LocalDate.now(),
        ): CalendarMonth {
            val firstOfMonth = LocalDate.of(year, month, 1)

            // DayOfWeek: MONDAY=1 .. SUNDAY=7. Sunday-first grid column index is
            // value % 7 (SUNDAY -> 0, MONDAY -> 1, ... SATURDAY -> 6).
            val leading = firstOfMonth.dayOfWeek.value % 7
            val dayCount = firstOfMonth.lengthOfMonth()

            val days = ArrayList<CalendarDay>(dayCount)
            for (d in 1..dayCount) {
                val date = LocalDate.of(year, month, d)
                // DayOfWeek: MONDAY=1..SUNDAY=7 → remap to 1=Sun..7=Sat
                val wd = date.dayOfWeek.value % 7 + 1
                val ordo = ContentStore.ordoForDate(date, rite)
                days.add(
                    CalendarDay(
                        date = date,
                        day = d,
                        weekday = wd,
                        ordo = ordo,
                        englishName = ordo?.let { ContentStore.ordoNameEnglish(it.name) },
                        isToday = date == today,
                    )
                )
            }

            return CalendarMonth(
                year = year,
                month = month,
                title = firstOfMonth.format(titleFormatter),
                leadingBlanks = leading,
                days = days,
            )
        }
    }
}
