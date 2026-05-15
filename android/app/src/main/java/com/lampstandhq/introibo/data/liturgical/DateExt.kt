package com.lampstandhq.introibo.data.liturgical

import java.time.LocalDate

/**
 * Extension functions on [LocalDate] that mirror the Swift `Date` helpers
 * used throughout the liturgical calendar code.
 */

/** Adds (or subtracts, with a negative) [n] days. */
fun LocalDate.addDays(n: Int): LocalDate = plusDays(n.toLong())

/** True if this date falls on the same calendar day as [other]. */
fun LocalDate.isSameDay(other: LocalDate): Boolean = this == other

/** True if this date is on or after [other]. */
fun LocalDate.isSameOrAfter(other: LocalDate): Boolean = !this.isBefore(other)

/** True if this date is on or before [other]. */
fun LocalDate.isSameOrBefore(other: LocalDate): Boolean = !this.isAfter(other)
