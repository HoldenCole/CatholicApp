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
            "ui_strings_es.json", "missal_propers_es.json",
            "missal_readings_es.json", "stations_es.json", "saints_es.json",
            "reference_es.json", "courses_es.json",
            "psalter_es.json", "psalter_weekly_es.json",
            "hours_parts_es.json",
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

            // UI chrome resolves Spanish; unknown keys keep the English
            // literal passed at the call site.
            assertEquals("Hoy", ContentStore.uiString("calendar.today", "Today"))
            assertEquals("Témporas", ContentStore.uiString("flag.ember_day", "Ember Day"))
            assertEquals("Fallback", ContentStore.uiString("no.such.key", "Fallback"))

            // Mass propers tranche: Advent I is covered — antiphons and
            // orations in Spanish, Latin untouched.
            val advent1 = ContentStore.allPropers.first { it.slug == "adv1-0" }
            assertTrue(advent1.introit.eng.startsWith("A ti, Señor, levanto mi alma"))
            assertTrue(advent1.introit.lat.startsWith("Ad te levávi"))
            assertTrue(advent1.collect.eng.startsWith("Despierta, Señor, tu potencia"))
            assertTrue(advent1.collect.eng.contains("Tú que vives y reinas"))
            // Tranche 2: Septuagesima (with the supplemented secreta) and Lent.
            val septuagesima = ContentStore.allPropers.first { it.slug == "quadp1-0" }
            assertTrue(septuagesima.introit.eng.startsWith("Me cercaron angustias de muerte"))
            assertTrue(septuagesima.secret.eng.startsWith("Recibidos, Señor"))
            val lent1 = ContentStore.allPropers.first { it.slug == "quad1-0" }
            assertTrue(lent1.introit.eng.startsWith("Si me invoca"))

            // Tranche 3: Easter Sunday (our supplemented formulary — DO's
            // Espanol Eastertide is stubs), Pentecost, and the
            // post-Pentecost Sundays.
            val easterProper = ContentStore.allPropers.first { it.slug == "pasc0-0" }
            assertTrue(easterProper.introit.eng.startsWith("Resucité, y aún estoy contigo"))
            assertTrue(easterProper.communion.eng.startsWith("Cristo, nuestra Pascua"))
            val pentecost = ContentStore.allPropers.first { it.slug == "pasc7-0" }
            assertTrue(pentecost.introit.eng.isNotBlank() &&
                !pentecost.introit.eng.startsWith("The Spirit of the Lord"))
            val trinity = ContentStore.allPropers.first { it.slug == "pent01-0" }
            assertTrue(trinity.introit.eng.startsWith("Bendita sea la Trinidad"))

            // Tranche 4: the Eastertide supplements — Low Sunday, the
            // octave, Ascension, and the Pentecost octave.
            val lowSunday = ContentStore.allPropers.first { it.slug == "pasc1-0" }
            assertTrue(lowSunday.introit.eng.startsWith("Como niños recién nacidos"))
            val ascension = ContentStore.allPropers.first { it.slug == "pasc5-4" }
            assertTrue(ascension.introit.eng.startsWith("Varones de Galilea"))
            assertTrue(ascension.collect.eng.contains("Por el mismo Jesucristo"))
            val whitMonday = ContentStore.allPropers.first { it.slug == "pasc7-1" }
            assertTrue(whitMonday.introit.eng.startsWith("Los alimentó con flor de trigo"))
            assertTrue(whitMonday.collect.eng.contains("del mismo Espíritu Santo"))

            // Tranche 5: the sanctoral cycle — DO Espanol orations plus our
            // commune line table (identical Latin -> identical Spanish).
            val assumption = ContentStore.allPropers.first { it.slug == "08-15" }
            assertTrue(assumption.introit.eng.startsWith("Un gran prodigio apareció en el cielo"))
            val peterPaul = ContentStore.allPropers.first { it.slug == "06-29" }
            assertTrue(peterPaul.communion.eng.startsWith("Tú eres Pedro"))
            val joseph = ContentStore.allPropers.first { it.slug == "03-19" }
            assertTrue(joseph.introit.eng.startsWith("El justo florecerá como la palma"))
            // The Triduum: Good Friday's rubric notes and the Easter Vigil.
            val goodFriday = ContentStore.allPropers.first { it.slug == "quad6-5" }
            assertTrue(goodFriday.secret.eng.startsWith("El Viernes Santo no se celebra la Misa"))
            val vigil = ContentStore.allPropers.first { it.slug == "quad6-6" }
            assertTrue(vigil.collect.eng.startsWith("Oh Dios, que iluminas esta sacratísima noche"))
            // Conclusion formulas expand exactly once (a doubled response
            // was the tranche-5 regression this pins against).
            assertTrue(!advent1.collect.eng.contains("Amén. Amén."))
            assertTrue(!vigil.collect.eng.contains("Amén. Amén."))

            // Tranche 6: name-parameterized commune templates — the abbot
            // collect (St Benedict), a papal martyr (St Polycarp), and a
            // hand-translated proper collect (St Monica).
            val benedict = ContentStore.allPropers.first { it.slug == "03-21" }
            assertTrue(benedict.collect.eng.startsWith(
                "Que nos recomiende, Señor, te rogamos, la intercesión de tu santo Abad Benito"))
            val polycarp = ContentStore.allPropers.first { it.slug == "01-26" }
            assertTrue(polycarp.collect.eng.contains("Mártir y Obispo Policarpo"))
            val monica = ContentStore.allPropers.first { it.slug == "05-04" }
            assertTrue(monica.collect.eng.contains("Santa Mónica"))

            // Tranche 7 (completion): the last hand-translated feasts —
            // Christ the King, All Saints, Candlemas, and All Souls' first
            // Mass. EVERY proper field in the missal now carries Spanish:
            // no day and no field falls back to English any more.
            val christKing = ContentStore.allPropers.first { it.slug == "10-du" }
            assertTrue(christKing.introit.eng.startsWith("Digno es el Cordero"))
            assertTrue(christKing.collect.eng.contains("Rey del universo"))
            val allSaints = ContentStore.allPropers.first { it.slug == "11-01" }
            assertTrue(allSaints.communion.eng.startsWith("Bienaventurados los limpios de corazón"))
            val candlemas = ContentStore.allPropers.first { it.slug == "02-02" }
            assertTrue(candlemas.communion.eng.startsWith("Simeón había recibido del Espíritu Santo"))
            val allSouls = ContentStore.allPropers.first { it.slug == "11-02m1" }
            assertTrue(allSouls.collect.eng.startsWith("Oh Dios, Creador y Redentor de todos los fieles"))

            // Scripture readings (Torres Amat, translated from the Vulgate):
            // intro heading + liturgical incipit + verse text, composed the
            // way a hand missal prints them.
            assertTrue(advent1.epistle.eng.startsWith(
                "Lección de la Epístola del Apóstol San Pablo a los Romanos\nHermanos:"))
            assertTrue(advent1.gospel.eng.startsWith(
                "Continuación + del santo Evangelio según San Lucas\nEn aquel tiempo:"))
            // A deuterocanonical pericope — our own tier-2 translation from
            // the Vulgate (the 66-book Torres Amat module lacks Judith).
            assertTrue(assumption.epistle.eng.startsWith("Lección del libro de Judit"))
            assertTrue(assumption.epistle.eng.contains("Tú, gloria de Jerusalén"))
            // Palm Sunday's Passion carries its own heading.
            val palmSunday = ContentStore.allPropers.first { it.slug == "quad6-0" }
            assertTrue(palmSunday.gospel.eng.startsWith(
                "Pasión de nuestro Señor Jesucristo según San Mateo"))
            // Deliberate exclusions keep their English: the Easter Vigil's
            // Exsultet-plus-prophecies block is not a plain pericope.
            assertTrue(vigil.epistle.eng.startsWith("Rejoice now, all ye heavenly Legions"))

            // Stations of the Cross: all fourteen carry Spanish title,
            // meditation, and Stabat verse; the Latin side is untouched.
            val first = ContentStore.stations.first()
            assertEquals("Jesús es condenado a muerte", first.title)
            assertTrue(first.med.startsWith("Pilato, sabiendo que Jesús es inocente"))
            assertTrue(first.stabatEng.startsWith("Estaba la Madre dolorosa"))
            assertTrue(first.latin.startsWith("Iesus ad mortem"))
            assertTrue(first.stabatLat.startsWith("Stabat Mater dolorósa"))
            val last = ContentStore.stations.last()
            assertEquals("Jesús es puesto en el sepulcro", last.title)
            assertTrue(last.stabatEng.endsWith("la gloria del paraíso. Amén."))

            // Saints' devotional programs: names, sections, practices, and
            // prayers in Spanish; Teresa's Letrilla returns to its ORIGINAL
            // Spanish; the Latin labels and prayer texts are untouched.
            val pio = ContentStore.saints.first { it.slug == "pio" }
            assertEquals("San Padre Pío", pio.name)
            assertEquals("Mañana", pio.sections[0].eng)
            assertEquals("Mane", pio.sections[0].lat)
            assertTrue(pio.sections[0].practices[0].t == "Ofrecimiento de la mañana")
            assertTrue(pio.penance!!.startsWith("Ofrece hoy un sufrimiento físico"))
            assertTrue(pio.prayers!![0].eng.startsWith("Quédate con nosotros, Señor"))
            assertTrue(pio.prayers!![0].latin!!.startsWith("Mane nobiscum"))
            val teresa = ContentStore.saints.first { it.slug == "teresa" }
            assertTrue(teresa.prayers!![0].eng.startsWith("Nada te turbe, nada te espante"))
            assertTrue(teresa.quote.startsWith("Nada te turbe"))

            // Reference encyclopedia: prose in Spanish, Latin names and
            // category labels untouched, scripture quote's English half
            // replaced, and the embedded <link> tag survives with its
            // target intact (the link scanner depends on it).
            val advent = ContentStore.reference.first { it.slug == "cal-advent" }
            assertEquals("Adviento", advent.title)
            assertEquals("Adventus Domini", advent.latin)
            assertEquals("Calendarium", advent.cat)
            assertTrue(advent.summary.startsWith("El tiempo litúrgico de preparación"))
            assertTrue(advent.scripture!!.eng.startsWith("He aquí que la virgen concebirá"))
            assertTrue(advent.scripture!!.lat.startsWith("Ecce virgo concipiet"))
            val penanceRef = ContentStore.reference.first { it.slug == "mass-penance" }
            assertTrue(penanceRef.practice!!.contains(
                "<link target=\"prayer:actusContr\">Acto de Contrición</link>"))
            // The Septuagesima category fix holds: no stray lowercase bucket.
            assertTrue(ContentStore.reference.none { it.cat == "calendar" })

            // Schola Latina: localized for Spanish speakers — the vowels
            // lesson addresses a Spanish ear, phonetics are re-keyed to
            // Spanish orthography, the Ave glosses use the received Spanish
            // prayer, and the Latin card fronts are untouched.
            val vowelsCourse = ContentStore.courses.first { it.slug == "vowels" }
            assertEquals("Las vocales eclesiásticas", vowelsCourse.title)
            assertEquals("De Vocalibus Ecclesiasticis", vowelsCourse.latin)
            assertTrue(vowelsCourse.sections[0].html!!.contains("las cinco del español"))
            val vowelCard = vowelsCourse.sections.first { it.type == "cards" }.items!![0]
            assertEquals("Dóminus", vowelCard.lat)
            assertEquals("DÓ-mi-nus", vowelCard.phon)
            assertEquals("Señor, Amo", vowelCard.eng)
            val aveCourse = ContentStore.courses.first { it.slug == "ave" }
            val avePhrases = aveCourse.sections.first { it.type == "phrase" }.items!!
            assertEquals("Dios te salve, María,", avePhrases[0].eng)

            // The Psalter (Office tranche O1): Torres Amat — DO's psalter
            // was REJECTED where it pasted the modern copyrighted
            // liturgical psalter (Ps 22, Ps 50…); those psalms now carry
            // the public-domain Torres Amat text, ref prefixes and flex
            // marks mirrored from the Latin.
            val ps1 = ContentStore.psalterTextData["psalm1"]!!["eng"]!!
            assertTrue(ps1[0].startsWith("1:1 Dichoso aquel varón"))
            assertTrue(ps1[0].contains("†") && ps1[0].contains("*"))
            val ps22 = ContentStore.psalterTextData["psalm22"]!!["eng"]!!
            assertTrue(ps22[0].startsWith("22:1 El Señor es mi pastor"))
            val ps50 = ContentStore.psalterTextData["psalm50"]!!["eng"]!!
            assertTrue(ps50[0].startsWith("50:3a Ten piedad de mí"))
            // Latin untouched.
            assertTrue(ContentStore.psalterTextData["psalm1"]!!["lat"]!![0]
                .startsWith("1:1 Beátus vir"))
            // The weekly fan-out carries the same lines.
            val mondayEs = ContentStore.psalterWeeklyData["monday"]!!
                .getValue("matutinum.psalm2").verses!![0]
            assertEquals("13:1a Dijo en su corazón el insensato: * No hay Dios.",
                mondayEs.eng)
            assertTrue(mondayEs.lat.startsWith("13:1a Dixit insípiens"))

            // The ordinary of the hours (O2): the opening versicle, the
            // received formulas, a traditional verse hymn, the Te Deum,
            // and the Benedictus — with the Latin untouched throughout.
            val matinsParts = ContentStore.hours.first { it.slug == "matutinum" }.parts
            assertEquals("Señor, ábreme los labios.", matinsParts[0].eng)
            assertEquals("Y mi boca proclamará tu alabanza.", matinsParts[0].engR)
            assertTrue(matinsParts[0].lat!!.startsWith("Dómine, lábia mea"))
            assertTrue(matinsParts[4].eng!!.startsWith("Eterno Hacedor del mundo"))
            assertTrue(matinsParts[74].verses!![0].eng
                .startsWith("A ti, oh Dios, te alabamos"))
            val laudes = ContentStore.hours.first { it.slug == "laudes" }
            assertTrue(laudes.parts[12].verses!![0].eng
                .startsWith("Bendito + sea el Señor, Dios de Israel"))
            val compline = ContentStore.hours.first { it.slug == "completorium" }
            assertTrue(compline.parts[17].eng!!.startsWith("Dios te salve, Reina"))

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
        assertEquals("Today", ContentStore.uiString("calendar.today", "Today"))
        val advent1 = ContentStore.allPropers.first { it.slug == "adv1-0" }
        assertTrue(advent1.introit.eng.startsWith("To You I lift up my soul") ||
            !advent1.introit.eng.startsWith("A ti, Señor"))
        val assumption = ContentStore.allPropers.first { it.slug == "08-15" }
        assertTrue(!assumption.introit.eng.startsWith("Un gran prodigio"))
        assertTrue(advent1.epistle.eng.startsWith("Lesson from the letter"))
        assertEquals("Jesus Is Condemned to Death", ContentStore.stations.first().title)
        assertEquals("St. Padre Pio", ContentStore.saints.first { it.slug == "pio" }.name)
        assertEquals("Advent", ContentStore.reference.first { it.slug == "cal-advent" }.title)
        assertEquals("Ecclesiastical Vowels", ContentStore.courses.first { it.slug == "vowels" }.title)
        assertTrue(ContentStore.psalterTextData["psalm1"]!!["eng"]!![0]
            .startsWith("1:1 Blessed is the man"))
        assertEquals("O Lord, Thou wilt open my lips.",
            ContentStore.hours.first { it.slug == "matutinum" }.parts[0].eng)
        // The English data fix that tranche 2 flushed out: Septuagesima's
        // secret is Muneribus nostris, not the C2a martyr's secret.
        val septuagesima = ContentStore.allPropers.first { it.slug == "quadp1-0" }
        assertTrue(septuagesima.secret.lat.startsWith("Munéribus nostris"))
        assertTrue(!septuagesima.secret.lat.contains("Accépta sit in conspéctu"))
    }
}
