package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * QA harness: dumps fully assembled offices for a matrix of rubrically
 * interesting dates (Tenebrae, O-antiphon days, Ember days, octaves,
 * commemorations, all three rites) as readable text, for human/rubrical
 * review. Output goes to build/office-qa-dumps (override with the
 * OFFICE_DUMP_DIR env var). Cheap enough to run with the suite; the files
 * it writes are build artifacts, never bundled.
 */
class OfficeDumpHarness {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory } ?: error("no assets")
    }

    private val outDir = File(System.getenv("OFFICE_DUMP_DIR") ?: "build/office-qa-dumps")

    @Test
    fun dump() {
        ContentStore.initFromDirectory(assets)
        outDir.mkdirs()

        val allHours = listOf(
            "matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium",
        )
        val lv = listOf("matutinum", "laudes", "vesperae")

        data class Case(val date: LocalDate, val rites: List<MissalRite>, val hours: List<String>, val note: String)
        val r62 = listOf(MissalRite.RITE_1962)
        val all3 = MissalRite.entries.toList()
        val cases = listOf(
            Case(LocalDate.of(2026, 7, 30), all3, allHours, "per-annum Thursday feria + commemoration Ss Abdon et Sennen"),
            Case(LocalDate.of(2026, 12, 8), all3, allHours, "Immaculate Conception, I class"),
            Case(LocalDate.of(2026, 8, 15), r62, lv, "Assumption, I class"),
            Case(LocalDate.of(2026, 7, 25), r62, lv, "St James Apostle"),
            Case(LocalDate.of(2026, 7, 29), r62, listOf("matutinum"), "St Martha III class (contracted lesson)"),
            Case(LocalDate.of(2025, 11, 30), r62, lv, "Advent I Sunday"),
            Case(LocalDate.of(2025, 12, 3), all3, listOf("laudes", "vesperae"), "Advent Wednesday feria (preces)"),
            Case(LocalDate.of(2025, 12, 18), r62, listOf("laudes", "vesperae", "tertia"), "O-antiphon feria"),
            Case(LocalDate.of(2025, 12, 25), r62, lv, "Christmas"),
            Case(LocalDate.of(2026, 1, 5), all3, listOf("laudes", "vesperae"), "Jan 5 feria (1962) / vigil (older rites)"),
            Case(LocalDate.of(2026, 1, 6), r62, lv, "Epiphany"),
            Case(LocalDate.of(2026, 2, 1), r62, lv, "Septuagesima Sunday (Laus tibi)"),
            Case(LocalDate.of(2026, 2, 18), r62, lv, "Ash Wednesday"),
            Case(LocalDate.of(2026, 2, 20), all3, allHours, "Lent Friday feria (preces; Vespers proper collect)"),
            Case(LocalDate.of(2026, 3, 25), r62, lv, "Annunciation in Lent"),
            Case(LocalDate.of(2026, 3, 29), r62, listOf("laudes", "vesperae"), "Passion Sunday (no Gloria Patri)"),
            Case(LocalDate.of(2026, 4, 2), all3, listOf("matutinum", "laudes"), "Maundy Thursday (Tenebrae)"),
            Case(LocalDate.of(2026, 4, 3), r62, listOf("matutinum", "vesperae"), "Good Friday"),
            Case(LocalDate.of(2026, 4, 5), r62, lv, "Easter Sunday"),
            Case(LocalDate.of(2026, 4, 8), r62, listOf("laudes", "tertia", "completorium"), "Easter octave Wednesday"),
            Case(LocalDate.of(2026, 5, 24), r62, lv, "Pentecost"),
            Case(LocalDate.of(2026, 5, 27), r62, listOf("laudes"), "Ember Wednesday in Pentecost octave"),
            Case(LocalDate.of(2026, 6, 4), r62, lv, "Corpus Christi"),
            Case(LocalDate.of(2026, 9, 19), all3, listOf("laudes", "vesperae"), "September Ember Saturday (preces)"),
            Case(LocalDate.of(2026, 10, 25), r62, lv, "Christ the King"),
            Case(LocalDate.of(2026, 11, 2), r62, lv, "All Souls"),
            Case(LocalDate.of(2026, 11, 18), all3, listOf("matutinum", "laudes", "vesperae"), "Dedication of the Basilicas (commune C8)"),
        )

        for (c in cases) {
            val sb = StringBuilder()
            sb.appendLine("### ${c.date} — ${c.note}")
            for (rite in c.rites) {
                val ordo = ContentStore.ordoForDate(c.date, rite)
                sb.appendLine()
                sb.appendLine("== RITE ${rite.rawValue}: ordo=${ordo?.name} winner=${ordo?.winner}/${ordo?.winnerKey} rank=${ordo?.rank} temporal=${ordo?.temporal} commem=${ordo?.commemoration}")
                for (slug in c.hours) {
                    val h = ContentStore.hourForDate(slug, c.date, rite) ?: continue
                    sb.appendLine("-- $slug (${h.parts.size} parts)")
                    for (p in h.parts) {
                        val vk = p.variationKey ?: "-"
                        val lat = (p.lat ?: p.verses?.firstOrNull()?.lat ?: "").replace("\n", " | ").take(110)
                        val ant = p.antiphonLat?.replace("\n", " | ")?.take(60)
                        sb.append("   [${p.type}/$vk] ${(p.label ?: "").take(40)}")
                        if (lat.isNotEmpty()) sb.append(" :: $lat")
                        if (ant != null) sb.append(" [ant: $ant]")
                        sb.appendLine()
                    }
                }
            }
            File(outDir, "${c.date}.txt").writeText(sb.toString())
        }
        println("dumped ${cases.size} cases to $outDir")
    }
}
