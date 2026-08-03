package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.ConfessionGuide
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.data.model.ExamenEntry
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.MissalProperEntry
import com.lampstandhq.introibo.data.model.MissalSection
import com.lampstandhq.introibo.data.model.MysterySetData
import com.lampstandhq.introibo.data.model.OrdoEntry
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.data.model.RosaryPrayer
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.data.model.Station
import kotlinx.serialization.json.Json
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/**
 * Decodes EVERY bundled JSON asset with the exact Json configuration and
 * target types ContentStore uses.
 *
 * ContentStore.load() swallows decode exceptions and returns null, so a
 * malformed asset does not crash the app — it silently empties a feature.
 * That happened twice with import-metadata keys (`officium`/`rank`) written
 * into the Office propers maps by import_do.py (see 2aab98a and
 * scripts/strip_propers_metadata.py). This test turns that silent failure
 * into a red build.
 */
class AssetsDecodeTest {

    // Spanish-overlay schemas, mirroring ContentStore's private decode types.
    @kotlinx.serialization.Serializable
    data class PrayerEsEntry(
        val title_es: String,
        val note_es: String? = null,
        val lines_es: List<String>,
    )

    @kotlinx.serialization.Serializable
    data class MarianEsEntry(val title_es: String, val body_es: String)

    @kotlinx.serialization.Serializable
    data class HourEsEntry(val name_es: String, val time_es: String, val intro_es: String)

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val assetsDir: File by lazy {
        // Unit-test working dir is the module dir (android/app); fall back a
        // level in case the runner starts at the project root.
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory }
            ?: error("cannot locate src/main/assets from ${File(".").absolutePath}")
    }

    private inline fun <reified T> decode(name: String): T {
        val f = File(assetsDir, name)
        assertTrue("$name missing from assets", f.isFile)
        return try {
            json.decodeFromString<T>(f.readText())
        } catch (e: Exception) {
            fail("$name failed to decode as ${T::class.simpleName}: ${e.message?.take(300)}")
            throw AssertionError() // unreachable
        }
    }

    @Test
    fun everyAssetDecodesWithContentStoreTypes() {
        val covered = mutableSetOf<String>()
        fun <T> check(name: String, body: () -> T, nonEmpty: (T) -> Boolean) {
            covered += name
            val v = body()
            assertTrue("$name decoded but is EMPTY — silent data loss", nonEmpty(v))
        }

        check("prayers.json", { decode<List<Prayer>>("prayers.json") }) { it.isNotEmpty() }
        check("reference.json", { decode<List<ReferenceEntry>>("reference.json") }) { it.isNotEmpty() }
        check("saints.json", { decode<List<Saint>>("saints.json") }) { it.isNotEmpty() }
        check("courses.json", { decode<List<Course>>("courses.json") }) { it.isNotEmpty() }
        check("missal.json", { decode<List<MissalSection>>("missal.json") }) { it.isNotEmpty() }
        check("mysteries.json", { decode<List<MysterySetData>>("mysteries.json") }) { it.isNotEmpty() }
        check("rosary_prayers.json", { decode<List<RosaryPrayer>>("rosary_prayers.json") }) { it.isNotEmpty() }
        check("stations.json", { decode<List<Station>>("stations.json") }) { it.isNotEmpty() }
        check("hours.json", { decode<List<Hour>>("hours.json") }) { it.isNotEmpty() }
        check("marian_antiphons.json", { decode<List<MarianAntiphonData>>("marian_antiphons.json") }) { it.isNotEmpty() }
        check("confession_examen.json", { decode<List<ExamenEntry>>("confession_examen.json") }) { it.isNotEmpty() }
        check("confession_guides.json", { decode<List<ConfessionGuide>>("confession_guides.json") }) { it.isNotEmpty() }
        // propers.json is intentionally [] — the bulk DO import (23bfadf) moved
        // all Mass propers into missal_tempora/missal_sanctoral; allPropers
        // derives from those. It must still DECODE, but empty is expected.
        check("propers.json", { decode<List<MassProper>>("propers.json") }) { true }
        check("missal_tempora.json", { decode<Map<String, MissalProperEntry>>("missal_tempora.json") }) { it.isNotEmpty() }
        check("missal_sanctoral.json", { decode<Map<String, MissalProperEntry>>("missal_sanctoral.json") }) { it.isNotEmpty() }
        check("sanctoral_propers.json", { decode<Map<String, Map<String, Hour.Part>>>("sanctoral_propers.json") }) { it.isNotEmpty() }
        check("commune_office.json", { decode<Map<String, Map<String, Hour.Part>>>("commune_office.json") }) { it.isNotEmpty() }
        check("saint_commune.json", { decode<Map<String, String>>("saint_commune.json") }) { it.isNotEmpty() }
        check("saint_office_inherit.json", { decode<Map<String, String>>("saint_office_inherit.json") }) { it.isNotEmpty() }
        check("ordo.json", { decode<Map<String, OrdoEntry>>("ordo.json") }) { it.isNotEmpty() }
        check("ordo_1955.json", { decode<Map<String, OrdoEntry>>("ordo_1955.json") }) { it.isNotEmpty() }
        check("ordo_pre1955.json", { decode<Map<String, OrdoEntry>>("ordo_pre1955.json") }) { it.isNotEmpty() }
        check("ordo_names_en.json", { decode<Map<String, String>>("ordo_names_en.json") }) { it.isNotEmpty() }
        check("canon_variants.json", { decode<Map<String, Map<String, Map<String, String>>>>("canon_variants.json") }) { it.isNotEmpty() }
        check("psalter_weekly.json", { decode<Map<String, Map<String, Hour.Part>>>("psalter_weekly.json") }) { it.isNotEmpty() }
        check("hymns_seasonal.json", { decode<Map<String, Map<String, Hour.Part>>>("hymns_seasonal.json") }) { it.isNotEmpty() }
        check("temporal_propers.json", { decode<Map<String, Map<String, Hour.Part>>>("temporal_propers.json") }) { it.isNotEmpty() }
        check("psalter.json", { decode<Map<String, Map<String, List<String>>>>("psalter.json") }) { it.isNotEmpty() }
        // Spanish vernacular overlay (ContentStore.applyVernacular).
        check("prayers_es.json", { decode<Map<String, PrayerEsEntry>>("prayers_es.json") }) { it.isNotEmpty() }
        check("marian_antiphons_es.json", { decode<Map<String, MarianEsEntry>>("marian_antiphons_es.json") }) { it.isNotEmpty() }
        check("hours_es.json", { decode<Map<String, HourEsEntry>>("hours_es.json") }) { it.isNotEmpty() }

        // Any asset shipped but not covered above would dodge this net —
        // force the list to stay in sync with the assets directory.
        val shipped = assetsDir.listFiles { f -> f.name.endsWith(".json") }!!.map { it.name }.toSet()
        val uncovered = shipped - covered
        assertTrue("assets not covered by this test: $uncovered", uncovered.isEmpty())
    }

    /** The Office propers maps must never contain scalar import metadata. */
    @Test
    fun propersMapsCarryNoScalarMetadata() {
        for (name in listOf("temporal_propers.json", "sanctoral_propers.json")) {
            val root = json.parseToJsonElement(File(assetsDir, name).readText())
            root.let { el ->
                val obj = el as kotlinx.serialization.json.JsonObject
                for ((day, entry) in obj) {
                    val e = entry as? kotlinx.serialization.json.JsonObject ?: continue
                    for ((k, v) in e) {
                        assertTrue(
                            "$name[$day].$k is a scalar (${v::class.simpleName}) — " +
                                "run scripts/strip_propers_metadata.py after re-importing",
                            v is kotlinx.serialization.json.JsonObject,
                        )
                    }
                }
            }
        }
    }
}
