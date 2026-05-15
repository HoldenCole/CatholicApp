package com.lampstandhq.introibo.data.liturgical

import java.time.LocalDate

/**
 * Anonymous Gregorian algorithm for computing Easter Sunday.
 * Faithful port of Introibo/Liturgical/Computus.swift -- do not alter
 * without cross-checking against the reference implementation, as every
 * downstream liturgical date depends on this.
 */
object Computus {

    /** Returns Easter Sunday of the given Gregorian [year]. */
    fun easterSunday(year: Int): LocalDate {
        val a = year % 19
        val b = year / 100
        val c = year % 100
        val d = b / 4
        val e = b % 4
        val f = (b + 8) / 25
        val g = (b - f + 1) / 3
        val h = (19 * a + b - d - g + 15) % 30
        val i = c / 4
        val k = c % 4
        val l = (32 + 2 * e + 2 * i - h - k) % 7
        val m = (a + 11 * h + 22 * l) / 451
        val month = (h + l - 7 * m + 114) / 31
        val day = ((h + l - 7 * m + 114) % 31) + 1

        return LocalDate.of(year, month, day)
    }

    /**
     * First Sunday of Advent of the given [year]. Computed as the Sunday
     * on or immediately before 27 November -- four Sundays before
     * Christmas Day, inclusive of Christmas Eve's Sunday if applicable.
     */
    fun firstSundayOfAdvent(year: Int): LocalDate {
        var d = LocalDate.of(year, 12, 25)
        // Walk back to the nearest Sunday on-or-before Christmas.
        while (d.dayOfWeek != java.time.DayOfWeek.SUNDAY) {
            d = d.minusDays(1)
        }
        // Three more Sundays back to get the First Sunday of Advent.
        d = d.minusDays(21)
        return d
    }
}
