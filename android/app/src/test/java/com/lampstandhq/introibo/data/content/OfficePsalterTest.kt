package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Psalter-substitution correctness for Lauds and Vespers (tester report:
 * "Sunday festal psalms override the weekday psalter").
 *
 * 1960 rubrics: the festal (Sunday) psalm scheme applies at Lauds on feasts
 * of every class, but at Vespers third-class feasts keep the FERIAL psalms —
 * Sunday psalms at Vespers belong to I/II class feasts only.
 */
class OfficePsalterTest {

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
    }

    private inline fun <reified T> load(name: String): T =
        json.decodeFromString(File(assets, name).readText())

    private val hours: List<Hour> by lazy { load("hours.json") }
    private val weekly: Map<String, Map<String, Hour.Part>> by lazy { load("psalter_weekly.json") }

    private val assembler by lazy {
        OfficeAssembler(
            weeklyPsalter = weekly,
            seasonalHymns = load("hymns_seasonal.json"),
            temporalPropers = load("temporal_propers.json"),
            marianAntiphons = load<List<MarianAntiphonData>>("marian_antiphons.json"),
            psalter = load("psalter.json"),
        )
    }

    private fun assembledPsalm1(slug: String, date: LocalDate, festal: Boolean): String? {
        val template = hours.first { it.slug == slug }
        val out = assembler.assemble(
            template = template,
            context = LiturgicalContext.forDate(date),
            isFestal = festal,
        )
        return out.parts.firstOrNull { it.variationKey == "$slug.psalm1" }?.label
    }

    @Test
    fun feriaGetsFerialPsalmsAtLaudsAndVespers() {
        // 2026-07-13 is a plain Monday feria (ordo rank 1.0 → isFestal=false).
        val monday = LocalDate.of(2026, 7, 13)
        assertEquals(
            weekly["monday"]!!["laudes.psalm1"]!!.label,
            assembledPsalm1("laudes", monday, festal = false),
        )
        assertEquals(
            weekly["monday"]!!["vesperae.psalm1"]!!.label,
            assembledPsalm1("vesperae", monday, festal = false),
        )
    }

    @Test
    fun thirdClassFeastKeepsFerialPsalms() {
        // 2026-07-14, S. Bonaventuræ (III class, ordo rank 3.0) — the exact
        // class the old rank >= 2.0 gate broke by forcing Sunday psalms.
        val ordo: Map<String, com.lampstandhq.introibo.data.model.OrdoEntry> = load("ordo.json")
        val rank = ordo["2026-07-14"]!!.rank
        org.junit.Assert.assertTrue("fixture must stay a III-class day", rank >= 2.0 && rank < 5.0)
        val festal = rank >= 5.0 // mirrors ContentStore.hourForToday's gate
        val tuesday = LocalDate.of(2026, 7, 14)
        assertEquals(
            weekly["tuesday"]!!["laudes.psalm1"]!!.label,
            assembledPsalm1("laudes", tuesday, festal),
        )
        assertEquals(
            weekly["tuesday"]!!["vesperae.psalm1"]!!.label,
            assembledPsalm1("vesperae", tuesday, festal),
        )
    }

    @Test
    fun festalFlagKeepsSundayPsalms() {
        // With isFestal=true the template's festal psalms must survive.
        val monday = LocalDate.of(2026, 7, 13)
        val template = hours.first { it.slug == "laudes" }
        val festalLabel = template.parts.first { it.variationKey == "laudes.psalm1" }.label
        assertEquals(festalLabel, assembledPsalm1("laudes", monday, festal = true))
    }
}
