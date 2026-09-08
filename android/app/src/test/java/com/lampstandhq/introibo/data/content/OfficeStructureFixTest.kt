package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import com.lampstandhq.introibo.data.model.MartyrologyData
import com.lampstandhq.introibo.storage.settings.MissalRite
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Pins the Office structural repair (user-reported: hours rendered only the
 * ferial psalter; Vespers had a monastic responsorium breve, the Sunday hymn
 * every day, a placeholder Magnificat antiphon, and Prime's fixed collect).
 *
 * Pure-JVM, real bundled data — same harness as OfficeAssemblerSmokeTest.
 */
class OfficeStructureFixTest {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory }
            ?: error("cannot locate assets dir")
    }

    private inline fun <reified T> load(name: String): T =
        json.decodeFromString(File(assets, name).readText())

    private val hours: List<Hour> by lazy { load("hours.json") }
    private val temporal: Map<String, Map<String, Hour.Part>> by lazy { load("temporal_propers.json") }
    private val sanctoral: Map<String, Map<String, Hour.Part>> by lazy { load("sanctoral_propers.json") }

    private val assembler by lazy {
        OfficeAssembler(
            weeklyPsalter = load("psalter_weekly.json"),
            seasonalHymns = load("hymns_seasonal.json"),
            temporalPropers = temporal,
            marianAntiphons = load<List<MarianAntiphonData>>("marian_antiphons.json"),
            psalter = load("psalter.json"),
            martyrology = load<MartyrologyData>("martyrology.json"),
        )
    }

    private fun assembled(
        slug: String,
        date: LocalDate,
        festal: Boolean = false,
        rite: MissalRite = MissalRite.RITE_1962,
        primeMartyrology: Boolean = true,
    ): Hour {
        val ctx = LiturgicalContext.forDate(date, rite = rite)
        return assembler.assemble(
            template = hours.first { it.slug == slug },
            context = ctx,
            isFestal = festal,
            festalCompline = festal,
            festalLittleHours = festal,
            matinsNocturns = if (festal) 3 else 1,
            matinsTeDeum = festal,
            rite = rite,
            primeMartyrology = primeMartyrology,
        )
    }

    @Test
    fun primeCarriesItsChapterOffice() {
        val prime = assembled("prima", feria)
        val keys = prime.parts.mapNotNull { it.variationKey }
        val second = keys.filter { it.startsWith("prima2.") || it == "lectio_prima" }
        assertEquals(
            listOf(
                "prima2.heading", "prima2.martyrologium", "prima2.pretiosa", "prima2.sanctamaria",
                "prima2.deusinadjutorium", "prima2.pater", "prima2.respice", "prima2.oratio",
                "prima2.benedictio1", "lectio_prima", "prima2.tuautem", "prima2.adjutorium",
                "prima2.benedictio2",
            ),
            second,
        )
        // The second part follows the Benedicámus of the first.
        assertTrue(
            prime.parts.indexOfFirst { it.variationKey == "prima2.heading" } >
                prime.parts.indexOfFirst { it.type == "closing" },
        )
        // The versicle after the brief responsory is Exsúrge, not the responsory again.
        assertTrue(prime.parts.first { it.variationKey == "versum_prima" }.lat.orEmpty().startsWith("℣. Exsúrge, Christe"))
        // The Martyrology is the morrow's (31 July: St Ignatius), headed by the Roman date and the Luna.
        val mart = prime.parts.first { it.variationKey == "prima2.martyrologium" }
        val lat = mart.lat.orEmpty()
        assertTrue(lat.startsWith("Prídie Kaléndas Augústi"))
        assertTrue(lat.contains("Luna ") && lat.contains("Anno Dómini 2026"))
        assertTrue(lat.contains("Ignátii"))
        assertTrue(lat.trimEnd().endsWith("℟. Deo grátias."))
        assertTrue(mart.eng.orEmpty().startsWith("July 31st, 2026, the "))
        assertTrue(mart.eng.orEmpty().contains("Ignatius"))
        // Movable-feast announcement, keyed by the MORROW's temporal code as in
        // Divinum Officium: the Easter proclamation is keyed pasc0-1, so it is
        // read at Prime on Easter Sunday itself (2027-03-28).
        val easter = assembled("prima", LocalDate.of(2027, 3, 28))
        assertTrue(easter.parts.first { it.variationKey == "prima2.martyrologium" }.lat.orEmpty()
            .contains("Hac die quam fecit Dóminus"))
        // ...and Maundy Thursday's is read on the Wednesday before it.
        val spyWed = assembled("prima", LocalDate.of(2027, 3, 24))
        assertTrue(spyWed.parts.first { it.variationKey == "prima2.martyrologium" }.lat.orEmpty()
            .contains("Cœna Domínica"))
        // 1960 "Jube, Dómine"; older rubrics "Jube, domne".
        assertTrue(prime.parts.first { it.variationKey == "prima2.benedictio1" }.lat.orEmpty().contains("Jube, Dómine"))
        val old = assembled("prima", feria, rite = MissalRite.RITE_1955)
        assertTrue(old.parts.first { it.variationKey == "prima2.benedictio1" }.lat.orEmpty().contains("Jube, domne"))
        // The toggle drops only the Martyrology, never the rest of the Chapter Office.
        val private = assembled("prima", feria, primeMartyrology = false)
        val pk = private.parts.mapNotNull { it.variationKey }
        assertFalse(pk.contains("prima2.martyrologium") || pk.contains("prima2.heading"))
        assertTrue(pk.contains("prima2.pretiosa") && pk.contains("prima2.benedictio2"))
    }

    // 2026-07-30 is a per-annum Thursday (Thursday in the 9th week after
    // Pentecost, temporal key pent09-4) — the exact day of the user report.
    private val feria: LocalDate = LocalDate.of(2026, 7, 30)

    @Test
    fun ferialVespersHasNoResponsoriumBreve() {
        val v = assembled("vesperae", feria)
        assertFalse(
            "Roman secular Vespers must not carry a responsorium breve",
            v.parts.any { (it.label ?: "").contains("Responsorium Breve") },
        )
    }

    @Test
    fun ferialVespersUsesTheWeekdayHymn() {
        val v = assembled("vesperae", feria)
        val hymn = v.parts.first { it.type == "hymn" }
        assertTrue(
            "Thursday Vespers hymn should be Magnae Deus potentiae, got ${hymn.lat?.take(40)}",
            hymn.lat.orEmpty().startsWith("Magnæ Deus poténtiæ"),
        )
    }

    @Test
    fun ferialVespersUsesTheWeekdayMagnificatAntiphon() {
        val v = assembled("vesperae", feria)
        val ant = v.parts.first { it.variationKey == "ant_vespera" }
        assertTrue(
            "Thursday Magnificat antiphon should be Fecit Deus potentiam, got ${ant.lat?.take(40)}",
            ant.lat.orEmpty().startsWith("Fecit Deus"),
        )
    }

    @Test
    fun ferialCollectInheritsFromThePrecedingSunday() {
        val expected = temporal["pent09-0"]?.get("oratio")?.lat
        assertNotNull("pent09-0 must carry the Sunday collect", expected)
        for (slug in listOf("laudes", "vesperae", "tertia")) {
            val h = assembled(slug, feria)
            val collect = h.parts.first { it.variationKey == "oratio" && it.type == "collect" }
            assertEquals("$slug should repeat the Sunday collect", expected, collect.lat)
        }
    }

    @Test
    fun primeAndComplineKeepTheirInvariableCollects() {
        val prime = assembled("prima", feria)
        val primeCollect = prime.parts.first { it.type == "collect" }
        assertTrue(
            "Prime's collect must stay Domine Deus omnipotens",
            primeCollect.lat.orEmpty().startsWith("Dómine Deus omnípotens"),
        )
        val compline = assembled("completorium", LocalDate.of(2026, 8, 2)) // a Sunday
        val complineCollect = compline.parts.first { it.type == "collect" }
        assertTrue(
            "Compline's collect must stay Visita quaesumus even on Sundays",
            complineCollect.lat.orEmpty().startsWith("Vísita"),
        )
    }

    @Test
    fun marianAntiphonCarriesItsVersicleAndPrayer() {
        fun suffix(date: LocalDate): Pair<Hour.Part?, Hour.Part?> {
            val parts = assembled("completorium", date).parts
            val i = parts.indexOfFirst { it.type == "marian" }
            assertTrue("Marian antiphon present on $date", i >= 0)
            return parts.getOrNull(i + 1) to parts.getOrNull(i + 2)
        }
        // Salve Regina (after Pentecost)
        val (salveVr, salveOr) = suffix(LocalDate.of(2026, 8, 2))
        assertTrue(salveVr?.type == "vr" && salveVr.lat.orEmpty().startsWith("℣. Ora pro nobis"))
        assertTrue(salveOr?.type == "collect" && salveOr.lat.orEmpty().startsWith("Omnípotens sempitérne Deus"))
        assertTrue(salveOr?.variationKey == "completorium.marian.oratio")
        // Alma Redemptoris: Advent form vs Christmas form
        val (adventVr, adventOr) = suffix(LocalDate.of(2026, 12, 6))
        assertTrue(adventVr?.lat.orEmpty().startsWith("℣. Angelus Dómini"))
        assertTrue(adventOr?.lat.orEmpty().startsWith("Grátiam tuam"))
        val (xmasVr, xmasOr) = suffix(LocalDate.of(2027, 1, 10))
        assertTrue(xmasVr?.lat.orEmpty().startsWith("℣. Post partum"))
        assertTrue(xmasOr?.lat.orEmpty().startsWith("Deus, qui salútis ætérnæ"))
        // Regina caeli in Paschaltide
        val (reginaVr, _) = suffix(LocalDate.of(2027, 4, 11))
        assertTrue(reginaVr?.lat.orEmpty().startsWith("℣. Gaude et lætáre"))
        // Triduum: nothing at all after the suppressed slot
        val triduum = assembled("completorium", LocalDate.of(2027, 3, 26)).parts
        assertTrue(triduum.none { it.type == "marian" })
        assertTrue(triduum.none { it.variationKey == "completorium.marian.versicle" })
    }

    @Test
    fun ferialLaudsUsesWeekdayHymnAntiphonAndVersicle() {
        val l = assembled("laudes", feria)
        val hymn = l.parts.first { it.type == "hymn" }
        assertTrue(
            "Thursday Lauds hymn should be Lux ecce surgit aurea, got ${hymn.lat?.take(40)}",
            hymn.lat.orEmpty().startsWith("Lux ecce surgit"),
        )
        val ant = l.parts.first { it.variationKey == "ant_laudes" }
        assertTrue(
            "Thursday Benedictus antiphon should be In sanctitate, got ${ant.lat?.take(40)}",
            ant.lat.orEmpty().startsWith("In sanctitáte"),
        )
        val versicle = l.parts.first { it.variationKey == "versum_1" }
        assertTrue(
            "Ferial Lauds versicle should be Repleti sumus mane",
            versicle.lat.orEmpty().startsWith("Repléti sumus"),
        )
    }

    @Test
    fun sundayCanticleAntiphonsLandOnTheCanticles() {
        // 2026-08-02 = 10th Sunday after Pentecost (pent10-0):
        //   ant_2 (Benedictus) = "Stans a longe...", ant_3 (Magnificat) =
        //   "Descendit hic justificatus...". Before the remap these DO keys
        //   collided with the Matins nocturn-antiphon slots.
        val sunday = LocalDate.of(2026, 8, 2)
        val lauds = assembled("laudes", sunday, festal = true)
        val bened = lauds.parts.first { it.variationKey == "ant_laudes" }
        assertTrue(
            "Sunday Benedictus antiphon should come from the Gospel (Stans a longe), got ${bened.lat?.take(40)}",
            bened.lat.orEmpty().startsWith("Stans a longe"),
        )
        val vespers = assembled("vesperae", sunday, festal = true)
        val magn = vespers.parts.first { it.variationKey == "ant_vespera" }
        assertTrue(
            "Sunday Magnificat antiphon should be Descendit hic justificatus, got ${magn.lat?.take(40)}",
            magn.lat.orEmpty().startsWith("Descéndit"),
        )
        val matins = assembled("matutinum", sunday, festal = true)
        assertFalse(
            "canticle antiphons must not leak onto Matins nocturn slots",
            matins.parts.any { it.lat.orEmpty().startsWith("Fecit Joas") },
        )
    }

    @Test
    fun feastRemapBindsProperVespersContent() {
        // Assumption (08-15): full propers. The remap must yield the proper
        // hymn, the 2nd-Vespers Magnificat antiphon (Ant 3 "Hodie Maria
        // Virgo caelos ascendit"), and the five psalm antiphons split out of
        // the Ant Vespera list.
        val raw = sanctoral["08-15"] ?: error("sanctoral 08-15 missing")
        val remapped = OfficeAssembler.remapProperOverrides(raw, "vesperae")
        assertTrue(
            "proper Magnificat antiphon should be Hodie Maria Virgo",
            remapped["ant_vespera"]?.lat.orEmpty().startsWith("Hódie"),
        )
        assertNotNull("proper Vespers hymn must survive the remap", remapped["hymnus_vespera"])
        assertTrue(
            "psalm antiphon 1 should be the first line of the Ant Vespera list",
            remapped["vesperae.antiphon.psalm1"]?.lat.orEmpty().startsWith("Assúmpta est María"),
        )
        // And at Matins the nocturn antiphons come from Ant Matutinum.
        val matins = OfficeAssembler.remapProperOverrides(raw, "matutinum")
        assertTrue(
            "nocturn 1 antiphon should come from Ant Matutinum (Exaltata est)",
            matins["ant_1"]?.lat.orEmpty().startsWith("Exaltáta est"),
        )
    }

    @Test
    fun thirdClassFeastKeepsItsLegendAtOneNocturnMatins() {
        // S. Marthae (07-29) ships only lectio4-9 (+ lectio94 contraction).
        // On a 1-nocturn Matins the contracted legend must reach lectio3.
        val raw = sanctoral["07-29"] ?: error("sanctoral 07-29 missing")
        assertTrue(
            "test premise: 07-29 has no lectio3 of its own",
            "lectio3" !in raw,
        )
        assertTrue(
            "test premise: 07-29 carries legend lessons",
            "lectio94" in raw || "lectio4" in raw,
        )
    }

    @Test
    fun saturdayVespersVersicleIsVespertinaOratio() {
        // Saturday, 2026-08-01 (per annum): V. Vespertina oratio ascendat.
        val sat = assembled("vesperae", LocalDate.of(2026, 8, 1))
        val versicle = sat.parts.first { it.variationKey == "versum_2" }
        assertTrue(
            "Saturday Vespers versicle should be Vespertina oratio, got ${versicle.lat?.take(40)}",
            versicle.lat.orEmpty().startsWith("Vespertína"),
        )
    }
}
