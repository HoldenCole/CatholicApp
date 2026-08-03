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
        for (name in listOf(
            "prayers_es.json", "marian_antiphons_es.json", "hours_es.json",
            "missal_es.json", "canon_variants_es.json", "ordo_names_es.json",
        )) {
            assertTrue(
                "$name drifted from spanish-translation/ — run scripts/sync_spanish_assets.py",
                File(staging, name).readBytes().contentEquals(File(assets, name).readBytes()),
            )
        }
    }

    @Test
    fun missalOverlayAlignsWithCoveredSections() {
        val source = parse("missal.json").jsonArray.associateBy(
            { it.jsonObject["slug"]!!.jsonPrimitive.content },
            { it.jsonObject["body"]!!.jsonArray.size },
        )
        val overlay = parse("missal_es.json").jsonObject
        for ((slug, entry) in overlay) {
            assertTrue("missal_es covers unknown section $slug", slug in source)
            assertEquals(
                "$slug line count",
                source[slug],
                entry.jsonObject["body_es"]!!.jsonArray.size,
            )
        }
        // Variant keys must exist in canon_variants.json.
        val srcVariants = parse("canon_variants.json").jsonObject
        for ((group, entries) in parse("canon_variants_es.json").jsonObject) {
            for (key in entries.jsonObject.keys) {
                assertTrue(
                    "canon_variants_es[$group][$key] has no source variant",
                    srcVariants[group]?.jsonObject?.containsKey(key) == true,
                )
            }
        }
        // Every Spanish feast name keys a name the English table knows.
        val enNames = parse("ordo_names_en.json").jsonObject.keys
        for (key in parse("ordo_names_es.json").jsonObject.keys) {
            assertTrue("ordo_names_es key not in ordo_names_en: $key", key in enNames)
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

            // Feast names render in Spanish.
            assertEquals("La Natividad de Nuestro Señor",
                ContentStore.ordoNameEnglish("In Nativitate Domini"))
            assertEquals("Domingo XXIII después de Pentecostés",
                ContentStore.ordoNameEnglish("De Dominica XXIII post Pentecosten"))

            // The Canon of the Mass is covered: Te igitur, the Communicantes
            // (with the Joseph anchor exactly once), and the doxology.
            val canon = ContentStore.missal.first { it.slug == "canon" }
            assertTrue(canon.body[0].eng.startsWith("Te pedimos, pues, Padre clementísimo"))
            assertTrue(canon.body[0].rubric == "El sacerdote ora en silencio:")
            val communicantes = canon.body.first { it.lat.startsWith("Communicántes") }
            assertEquals(1, communicantes.eng.split(": y también de tus bienaventurados Apóstoles").size - 1)
            assertTrue(communicantes.eng.endsWith("Por el mismo Cristo nuestro Señor. Amén."))
            assertTrue(canon.body[17].eng.startsWith("Por todos los siglos"))
            // Latin untouched.
            assertTrue(canon.body[0].lat.startsWith("Te ígitur"))

            // Proper Communicantes variants carry Spanish too.
            val easter = ContentStore.canonVariant("communicantes", "easter")
            assertTrue(easter!!.second.startsWith("Unidos en una misma comunión, y celebrando el día sacratísimo de la Resurrección"))
            assertTrue(easter.first.startsWith("Communicántes"))
            val hanc = ContentStore.canonVariant("hanc_igitur", "pentecost")
            assertTrue(hanc!!.second.contains("regenerar por el agua y el Espíritu Santo"))

            // The whole Ordinary is covered — spot-check the people's parts.
            val sanctus = ContentStore.missal.first { it.slug == "sanctus" }
            assertTrue(sanctus.body[0].eng.startsWith("Santo, Santo, Santo"))
            val gloria = ContentStore.missal.first { it.slug == "gloria" }
            assertTrue(gloria.body[0].eng.startsWith("Gloria a Dios en las alturas"))
            val credo = ContentStore.missal.first { it.slug == "credo" }
            assertTrue(credo.body[0].eng.startsWith("Creo en un solo Dios"))
            val ultimum = ContentStore.missal.first { it.slug == "ultimum" }
            assertTrue(ultimum.body[1].eng.startsWith("En el principio era el Verbo"))
            // Every section is overlaid — a line-count mismatch would leave a
            // section silently English. The English texts begin "We/I/O/May/
            // It is truly/The/Go/Let/World…"; none begins like these:
            for (s in ContentStore.missal) {
                assertTrue("${s.slug} appears to have kept its English body",
                    !s.body[0].eng.startsWith("We ") &&
                        !s.body[0].eng.startsWith("It is truly") &&
                        !s.body[0].eng.startsWith("I confess") &&
                        !s.body[0].eng.startsWith("I will go"))
            }
        } finally {
            ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
        }

        // English restored for the rest of the suite.
        val pater = ContentStore.prayers.first { it.slug == "pater" }
        assertTrue(pater.lines[0].eng.startsWith("Our Father"))
        assertEquals("Matins", ContentStore.hours.first { it.slug == "matutinum" }.eng)
        val canon = ContentStore.missal.first { it.slug == "canon" }
        assertTrue(canon.body[0].eng.startsWith("We therefore humbly pray"))
        assertTrue(ContentStore.canonVariant("communicantes", "easter")!!
            .second.startsWith("Communicating, and celebrating"))
        assertEquals("The Nativity of Our Lord",
            ContentStore.ordoNameEnglish("In Nativitate Domini"))
    }
}
