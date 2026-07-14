package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.storage.settings.PenanceDiscipline
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * Ember-day regression tests (iOS parity).
 *
 * The original Kotlin port compared ISO Monday-start weeks where iOS uses
 * Sunday-start weeks (Calendar.liturgical), which put the Advent Ember fast a
 * week early, broke September when the 14th fell on a Sunday, and the badge
 * path was missing the Pentecost and September seasons entirely.
 */
class EmberDaysTest {

    private fun ember(date: LocalDate): Boolean =
        LiturgicalContext.forDate(date, PenanceDiscipline.DISCIPLINE_1917)
            .penance.title.startsWith("Ember")

    // ---- Penance path (1917 discipline) ----

    @Test
    fun adventEmberDaysFallInTheThirdWeekOfAdvent2026() {
        // Advent I 2026 = Nov 29; Gaudete = Dec 13; Ember Wed/Fri/Sat = Dec 16/18/19.
        assertTrue(ember(LocalDate.of(2026, 12, 16)))
        assertTrue(ember(LocalDate.of(2026, 12, 18)))
        assertTrue(ember(LocalDate.of(2026, 12, 19)))
        // The week the broken ISO comparison used to flag (one week early):
        assertFalse(ember(LocalDate.of(2026, 12, 9)))
        assertFalse(ember(LocalDate.of(2026, 12, 11)))
        assertFalse(ember(LocalDate.of(2026, 12, 12)))
    }

    @Test
    fun pentecostEmberDaysFallInThePentecostOctave2026() {
        // Pentecost 2026 = May 24; Ember Wed/Fri/Sat = May 27/29/30.
        assertTrue(ember(LocalDate.of(2026, 5, 27)))
        assertTrue(ember(LocalDate.of(2026, 5, 29)))
        assertTrue(ember(LocalDate.of(2026, 5, 30)))
    }

    @Test
    fun septemberEmberDaysWhenSept14IsASunday() {
        // Sept 14 2025 is a Sunday. The ordo's "Quattuor Temporum Septembris"
        // days that year are Sep 24/26/27 — the week AFTER the week containing
        // Sept 14 (the badge path's reckoning; the penance path used to sit a
        // week early, contradicting the calendar's own Ember days).
        assertTrue(ember(LocalDate.of(2025, 9, 24)))
        assertTrue(ember(LocalDate.of(2025, 9, 26)))
        assertTrue(ember(LocalDate.of(2025, 9, 27)))
        assertFalse(ember(LocalDate.of(2025, 9, 17)))
        assertFalse(ember(LocalDate.of(2025, 9, 10)))
    }

    @Test
    fun septemberEmberDaysOrdinaryYear2026() {
        // Sept 14 2026 is a Monday (week Sep 13–19); the ordo's Ember days are
        // Sep 23/25/26 in the following week.
        assertTrue(ember(LocalDate.of(2026, 9, 23)))
        assertTrue(ember(LocalDate.of(2026, 9, 25)))
        assertTrue(ember(LocalDate.of(2026, 9, 26)))
        assertFalse(ember(LocalDate.of(2026, 9, 16)))
    }

    // ---- Badge path (LiturgicalContext.isEmberDay extension) ----

    @Test
    fun badgeCoversAllFourEmberSeasons() {
        // Advent (season-gated)
        assertTrue(LiturgicalContext.forDate(LocalDate.of(2026, 12, 16)).isEmberDay)
        // Lent: Ash Wednesday week (iOS badge semantics), Ash Wed 2026 = Feb 18
        assertTrue(LiturgicalContext.forDate(LocalDate.of(2026, 2, 20)).isEmberDay)
        // Pentecost: same Sunday-start week as Pentecost Sunday (May 24 2026)
        assertTrue(LiturgicalContext.forDate(LocalDate.of(2026, 5, 27)).isEmberDay)
        // September: week AFTER the one containing Sept 14 (iOS badge is +1)
        assertTrue(LiturgicalContext.forDate(LocalDate.of(2026, 9, 23)).isEmberDay)
        // Non-ember weekday
        assertFalse(LiturgicalContext.forDate(LocalDate.of(2026, 7, 1)).isEmberDay)
    }
}
