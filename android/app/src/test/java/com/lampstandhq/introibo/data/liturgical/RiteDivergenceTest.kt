package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.storage.settings.MissalRite
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * The app's flagship claim: switching rite (1962 / 1955 / pre-1955) changes
 * the liturgy everywhere. These tests pin the pure rite-divergent paths and
 * the data invariants the dynamic behavior depends on.
 */
class RiteDivergenceTest {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
    }

    private fun ordo(name: String): JsonObject =
        Json.parseToJsonElement(File(assets, name).readText()).jsonObject

    // ---- ProperCalendar / LiturgicalContext honor the rite ----

    @Test
    fun may1DivergesByRite() {
        val may1 = LocalDate.of(2026, 5, 1)
        assertEquals("st-joseph-worker", ProperCalendar.properSlug(may1, rite = MissalRite.RITE_1962))
        assertEquals("st-joseph-worker", ProperCalendar.properSlug(may1, rite = MissalRite.RITE_1955))
        assertEquals("sts-philip-james", ProperCalendar.properSlug(may1, rite = MissalRite.PRE_1955))

        // The context path must propagate the rite into properSlug.
        assertEquals(
            "sts-philip-james",
            LiturgicalContext.forDate(may1, rite = MissalRite.PRE_1955).properSlug,
        )
        assertNotEquals(
            LiturgicalContext.forDate(may1, rite = MissalRite.PRE_1955).properSlug,
            LiturgicalContext.forDate(may1, rite = MissalRite.RITE_1962).properSlug,
        )
    }

    // ---- Data invariants behind the dynamism ----

    @Test
    fun ordosGenuinelyDiverge() {
        val o62 = ordo("ordo.json")
        val o55 = ordo("ordo_1955.json")
        val opre = ordo("ordo_pre1955.json")
        val shared = o62.keys intersect o55.keys intersect opre.keys
        assertTrue("rites must share a date range", shared.size > 2000)

        fun name(o: JsonObject, k: String) =
            o[k]?.jsonObject?.get("name")?.jsonPrimitive?.content

        val d62v55 = shared.count { name(o62, it) != name(o55, it) }
        val d62vPre = shared.count { name(o62, it) != name(opre, it) }
        // If either drops near zero, a regeneration flattened the rites and
        // the rite switch silently stopped doing anything.
        assertTrue("1962 vs 1955 divergence collapsed: $d62v55", d62v55 > shared.size / 10)
        assertTrue("1962 vs pre-1955 divergence collapsed: $d62vPre", d62vPre > shared.size / 10)
    }

    @Test
    fun everySanctoralWinnerHasMassAndOfficePropersInAllRites() {
        val ms = Json.parseToJsonElement(File(assets, "missal_sanctoral.json").readText()).jsonObject
        val sp = Json.parseToJsonElement(File(assets, "sanctoral_propers.json").readText()).jsonObject
        val sc = Json.parseToJsonElement(File(assets, "saint_commune.json").readText()).jsonObject

        for (name in listOf("ordo.json", "ordo_1955.json", "ordo_pre1955.json")) {
            val o = ordo(name)
            val winners = o.values.mapNotNull { e ->
                val obj = e.jsonObject
                if (obj["winner"]?.jsonPrimitive?.content == "sanctoral")
                    obj["winnerKey"]?.jsonPrimitive?.content else null
            }.toSet()
            val noMass = winners.filter { it !in ms && it.take(5) !in ms }
            val noOffice = winners.filter {
                it !in sp && it.take(5) !in sp && it !in sc && it.take(5) !in sc
            }
            assertTrue("$name winners without Mass propers: $noMass", noMass.isEmpty())
            assertTrue("$name winners without Office propers: $noOffice", noOffice.isEmpty())
        }
    }
}
