package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.VernacularLanguage
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Spanish vernacular overlay: alignment of the bundled *_es.json files with
 * their sources (the CI mirror of scripts/validate_spanish.py), and the
 * behavior of ContentStore.applyVernacular — Spanish lands where covered,
 * English restores on switch-back.
 */
class SpanishOverlayQA {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory }
            ?: error("cannot locate assets dir")
    }

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private fun parse(name: String) =
        json.parseToJsonElement(File(assets, name).readText())

    // ---- Alignment (validator mirror, enforced by the test suite) ----

    @Test
    fun prayersOverlayAlignsWithSource() {
        val source = parse("prayers.json").jsonArray.associateBy(
            { it.jsonObject["slug"]!!.jsonPrimitive.content },
            { it.jsonObject["lines"]!!.jsonArray.size },
        )
        val overlay = parse("prayers_es.json").jsonObject
        assertEquals("every prayer must be covered", source.keys, overlay.keys)
        for ((slug, entry) in overlay) {
            val lines = entry.jsonObject["lines_es"]!!.jsonArray.size
            assertEquals("$slug line count", source[slug], lines)
        }
    }

    @Test
    fun antiphonAndHourOverlaysAlignWithSources() {
        val antiphons = parse("marian_antiphons.json").jsonArray
            .map { it.jsonObject["slug"]!!.jsonPrimitive.content }.toSet()
        assertEquals(antiphons, parse("marian_antiphons_es.json").jsonObject.keys)

        val hours = parse("hours.json").jsonArray
            .map { it.jsonObject["slug"]!!.jsonPrimitive.content }.toSet()
        assertEquals(hours, parse("hours_es.json").jsonObject.keys)
    }

    @Test
    fun overlayFilesAreByteIdenticalToStaging() {
        val staging = File(assets, "../../../../../spanish-translation").canonicalFile
        // Staging only exists in the repo checkout; skip quietly elsewhere.
        if (!staging.isDirectory) return
        for (name in listOf("prayers_es.json", "marian_antiphons_es.json", "hours_es.json")) {
            assertTrue(
                "$name drifted from spanish-translation/ — run scripts/sync_spanish_assets.py",
                File(staging, name).readBytes().contentEquals(File(assets, name).readBytes()),
            )
        }
    }

    // ---- Behavior ----

    @Test
    fun spanishOverlayAppliesAndRestores() {
        ContentStore.initFromDirectory(assets)
        try {
            ContentStore.applyVernacular(VernacularLanguage.SPANISH)

            val pater = ContentStore.prayers.first { it.slug == "pater" }
            assertEquals("El Padrenuestro", pater.eng)
            assertTrue(pater.lines[0].eng.startsWith("Padre nuestro, que estás en los cielos"))
            // Latin side untouched.
            assertTrue(pater.lines[0].lat.startsWith("Pater noster"))

            val litany = ContentStore.prayers.first { it.slug == "litaniaeSacriCordis" }
            assertTrue(litany.lines[8].eng.startsWith("Corazón de Jesús"))

            val salve = ContentStore.marianAntiphons.first { it.slug == "salve" }
            assertTrue(salve.engBody.startsWith("Dios te salve, Reina y Madre"))

            val matins = ContentStore.hours.first { it.slug == "matutinum" }
            assertEquals("Maitines", matins.eng)
            assertEquals("a medianoche", matins.time)

            // Corpora outside the tranche stay English (safe fallback).
            val canon = ContentStore.missal.first { it.slug == "canon" }
            assertTrue(canon.body[0].eng.startsWith("Wherefore") ||
                canon.body[0].eng.startsWith("We ") || canon.body[0].eng.contains("Father"))
        } finally {
            ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
        }

        // English restored for the rest of the suite.
        val pater = ContentStore.prayers.first { it.slug == "pater" }
        assertTrue(pater.lines[0].eng.startsWith("Our Father"))
        assertEquals("Matins", ContentStore.hours.first { it.slug == "matutinum" }.eng)
    }
}
