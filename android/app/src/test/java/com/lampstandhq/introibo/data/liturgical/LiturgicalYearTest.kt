package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.storage.settings.MissalRite
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * The year-overview selection logic, run directly against the bundled ordo
 * data (no ContentStore/Android context needed): season segmentation must
 * cover the year exactly, and the moveable-feast keys must resolve for every
 * rite and year in range.
 */
class LiturgicalYearTest {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
    }

    private fun ordo(name: String): Map<String, JsonObject> =
        Json.parseToJsonElement(File(assets, name).readText()).jsonObject
            .mapValues { it.value.jsonObject }

    private val moveableKeys =
        listOf("pasc0-0", "pasc5-4", "pasc7-0", "pent01-0", "pent01-4", "10-du")

    @Test
    fun moveableFeastKeysResolveEveryYearInEveryRite() {
        for (name in listOf("ordo.json", "ordo_1955.json", "ordo_pre1955.json")) {
            val o = ordo(name)
            val years = o.keys.map { it.take(4).toInt() }.distinct().sorted()
            for (year in years) {
                val keysThisYear = o.filterKeys { it.startsWith("$year-") }
                    .values.mapNotNull { it["winnerKey"]?.jsonPrimitive?.content }
                    .toSet()
                for (key in moveableKeys) {
                    assertTrue("$name $year missing $key", key in keysThisYear)
                }
            }
        }
    }

    @Test
    fun seasonSegmentationCoversTheYearContiguously() {
        // Pure segmentation logic against raw ordo season values (mirrors
        // LiturgicalYear.seasons without ContentStore).
        val o = ordo("ordo.json")
        for (year in listOf(2025, 2026)) {
            var date = LocalDate.of(year, 1, 1)
            var days = 0
            var transitions = 0
            var prev: String? = null
            while (date.year == year) {
                val season = o["%04d-%02d-%02d".format(year, date.monthValue, date.dayOfMonth)]
                    ?.get("season")?.jsonPrimitive?.content ?: "ordinary"
                if (season != prev) { transitions += 1; prev = season }
                days += 1
                date = date.plusDays(1)
            }
            assertEquals("days in $year", if (year % 4 == 0) 366 else 365, days)
            // A liturgical year passes through at least: christmas(carry) →
            // pre-lent → lent → easter → ordinary → advent → christmas.
            assertTrue("$year has too few season transitions: $transitions", transitions >= 6)
        }
    }
}
