package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.storage.settings.MissalRite
import java.time.LocalDate

// MARK: - LiturgicalYear (year-overview + upcoming-feasts model)
//
// Pure, side-effect-free models for the year-at-a-glance surfaces: the season
// bands ("where am I in the year"), the major-feast markers, the moveable
// feasts quick-jump, and the upcoming-feasts preview. All liturgical knowledge
// is delegated to the bundled ordo via ContentStore — this file only selects
// and groups.
//
// iOS mirror:
//   Introibo/Liturgical/LiturgicalYear.swift

/** A run of consecutive days sharing one liturgical season. */
data class SeasonSegment(
    val seasonKey: String,   // ordo `season` value ("advent", "lent", ...)
    val label: String,       // display label ("Advent", "Lent", ...)
    val startDate: LocalDate,
    val endDate: LocalDate,
    val dayCount: Int,
) {
    companion object {
        val labels = mapOf(
            "advent" to "Advent",
            "christmas" to "Christmastide",
            "pre-lent" to "Pre-Lent",
            "lent" to "Lent",
            "easter" to "Eastertide",
            "ordinary" to "Time after Pentecost",
        )
    }
}

/** A major feast marked on the year overview. */
data class YearMarker(
    val date: LocalDate,
    val name: String,        // Latin ordo name
    val english: String?,    // bundled translation if any
    val color: String,       // ordo colour key
)

object LiturgicalYear {

    // ---- Season bands ----

    /** The year's season runs, in date order, under [rite]. */
    fun seasons(year: Int, rite: MissalRite): List<SeasonSegment> {
        val segments = mutableListOf<SeasonSegment>()
        var runKey: String? = null
        var runStart: LocalDate? = null
        var runEnd: LocalDate? = null
        var runDays = 0

        fun flush() {
            val key = runKey ?: return
            // A year has TWO "ordinary" runs: Time after Epiphany (starts in
            // January) and Time after Pentecost. Label them apart.
            val label = if (key == "ordinary" && runStart!!.monthValue <= 2) {
                "Time after Epiphany"
            } else {
                SeasonSegment.labels[key] ?: key.replaceFirstChar { it.uppercase() }
            }
            segments.add(
                SeasonSegment(
                    seasonKey = key,
                    label = label,
                    startDate = runStart!!,
                    endDate = runEnd!!,
                    dayCount = runDays,
                ),
            )
        }

        for (date in daysOfYear(year)) {
            val season = ContentStore.ordoForDate(date, rite)?.season ?: "ordinary"
            if (season == runKey) {
                runEnd = date
                runDays += 1
            } else {
                flush()
                runKey = season
                runStart = date
                runEnd = date
                runDays = 1
            }
        }
        flush()
        return segments
    }

    // ---- Major feasts ----

    /**
     * Temporal keys always marked: Holy Week core + the paschal-cycle feasts.
     * (These carry `winner == "temporal"`, so the sanctoral-rank filter below
     * never sees them.)
     */
    private val markerTemporalKeys = setOf(
        "quad6-0",   // Palm Sunday
        "quad6-4",   // Maundy Thursday
        "quad6-5",   // Good Friday
        "pasc0-0",   // Easter
        "pasc5-4",   // Ascension
        "pasc7-0",   // Pentecost
        "pent01-0",  // Trinity Sunday
        "pent01-4",  // Corpus Christi
    )

    /**
     * The year's major feasts under [rite]: first-class sanctoral days plus
     * the fixed temporal set above. Vigils are not markers.
     */
    fun markers(year: Int, rite: MissalRite): List<YearMarker> {
        val out = mutableListOf<YearMarker>()
        for (date in daysOfYear(year)) {
            val ordo = ContentStore.ordoForDate(date, rite) ?: continue
            val isTemporalMarker =
                ordo.winner == "temporal" && ordo.winnerKey in markerTemporalKeys
            val isSanctoralMajor =
                ordo.winner == "sanctoral" && ordo.rank >= 6.0 &&
                    !ordo.name.startsWith("In Vigilia")
            if (isTemporalMarker || isSanctoralMajor) {
                out.add(
                    YearMarker(
                        date = date,
                        name = ordo.name,
                        english = ContentStore.ordoNameEnglish(ordo.name),
                        color = ordo.color,
                    ),
                )
            }
        }
        return out
    }

    // ---- Moveable feasts (quick jump) ----

    /** Display order for the moveable-feast jump menu. */
    val moveableFeasts = listOf(
        "Easter" to "pasc0-0",
        "Ascension" to "pasc5-4",
        "Pentecost" to "pasc7-0",
        "Trinity Sunday" to "pent01-0",
        "Corpus Christi" to "pent01-4",
        "Christ the King" to "10-du",
    )

    /** Resolves the moveable feasts' dates for [year] under [rite]. */
    fun moveableDates(year: Int, rite: MissalRite): List<Pair<String, LocalDate>> {
        val byKey = mutableMapOf<String, LocalDate>()
        for (date in daysOfYear(year)) {
            val ordo = ContentStore.ordoForDate(date, rite) ?: continue
            byKey.putIfAbsent(ordo.winnerKey, date)
        }
        return moveableFeasts.mapNotNull { (label, key) ->
            byKey[key]?.let { label to it }
        }
    }

    // ---- Upcoming feasts ----

    /**
     * The notable days in the next [window] days (exclusive of today): feasts
     * of III class and above, vigils, and Ember days.
     */
    fun upcoming(
        start: LocalDate = LocalDate.now(),
        window: Int = 14,
        rite: MissalRite,
    ): List<CalendarDay> {
        val out = mutableListOf<CalendarDay>()
        for (offset in 1..window) {
            val date = start.plusDays(offset.toLong())
            val ordo = ContentStore.ordoForDate(date, rite) ?: continue
            val ctx = LiturgicalContext.forDate(date, rite = rite)
            val notable = ordo.rank >= 3.0 ||
                ordo.name.contains("vigilia", ignoreCase = true) ||
                ctx.isEmberDay
            if (!notable) continue
            out.add(
                CalendarDay(
                    date = date,
                    day = date.dayOfMonth,
                    weekday = date.dayOfWeek.value % 7 + 1,
                    ordo = ordo,
                    englishName = ContentStore.ordoNameEnglish(ordo.name),
                    isToday = false,
                    isEmberDay = ctx.isEmberDay,
                ),
            )
        }
        return out
    }

    // ---- Helpers ----

    /** Every day of [year] in order. */
    private fun daysOfYear(year: Int): Sequence<LocalDate> = sequence {
        var d = LocalDate.of(year, 1, 1)
        while (d.year == year) {
            yield(d)
            d = d.plusDays(1)
        }
    }
}
