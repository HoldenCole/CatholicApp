package com.lampstandhq.introibo.data.widget

import com.lampstandhq.introibo.data.liturgical.OfficeSchedule
import com.lampstandhq.introibo.data.model.Hour
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The widget's time logic: OfficeSchedule boundary behavior against the real
 * bundled hours (the same data the widget renders), including the just-before
 * / just-after boundary cases where time bugs cluster.
 */
class WidgetSlotLogicTest {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val hours: List<Hour> by lazy {
        val f = listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it, "hours.json") }.first { it.exists() }
        json.decodeFromString<List<Hour>>(f.readText())
    }

    @Test
    fun hoursDataHasCanonicalSchedule() {
        assertTrue("expected the full cursus", hours.size >= 7)
        // Every hour carries a schedulable time.
        for (h in hours) {
            assertTrue("${h.slug} time out of range", h.hour in 0..23 && h.minute in 0..59)
        }
    }

    @Test
    fun boundaryJustBeforeAndAfter() {
        // For every distinct boundary time: at the boundary the widget shows
        // the hour scheduled there (ties go to list order — e.g. Matutinum
        // over the Office of the Dead at midnight, matching the Office tab);
        // one minute before, it still shows the previous boundary's hour.
        val times = hours.map { it.hour * 60 + it.minute }.distinct().sorted()
        fun winnerAt(t: Int): String = hours.first { it.hour * 60 + it.minute == t }.slug
        for (i in 1 until times.size) {
            val t = times[i]
            assertEquals(
                "at boundary $t",
                winnerAt(t),
                OfficeSchedule.currentHourSlug(hours, t),
            )
            assertEquals(
                "minute before boundary $t",
                winnerAt(times[i - 1]),
                OfficeSchedule.currentHourSlug(hours, t - 1),
            )
        }
    }

    @Test
    fun beforeFirstHourRollsBackToCompletorium() {
        val first = hours.minOf { it.hour * 60 + it.minute }
        if (first > 0) {
            assertEquals("completorium", OfficeSchedule.currentHourSlug(hours, first - 1))
        }
    }
}
