package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Full-corpus sanity sweep of the Divine Office: every canonical hour, every
 * day of a complete liturgical cycle (Advent 2025 - Dec 2026), all three
 * rites, through the REAL ContentStore pipeline.
 *
 * Content correctness is pinned against Divinum Officium by
 * OfficeDivinumOfficiumGoldenTest; this sweep checks what that comparison
 * does not see: nothing throws, every hour has parts, every psalm and
 * canticle carries its verses, and no Divinum Officium markup
 * ("@File:Section", "&psalm(…)", "$Oremus", "!Title", "(rubrica …)")
 * leaks into the texts the reader sees.
 */
class OfficeFullSweepQA {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory }
            ?: error("cannot locate assets dir")
    }

    private val hours = listOf("matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium")

    private val markup = Regex("(^|\\n)\\s*(@[A-Za-z]|&[a-z_]+\\(|\\$[A-Z]|!Commemoratio|\\(rubrica |\\(sed |\\(deinde )")

    @Test
    fun fullCycleStructuralInvariants() {
        ContentStore.initFromDirectory(assets)
        val violations = mutableListOf<String>()
        fun flag(msg: String) { if (violations.size < 400) violations.add(msg) }

        var date = LocalDate.of(2025, 11, 29) // eve of Advent I 2025
        val end = LocalDate.of(2026, 12, 31)
        var runs = 0
        while (!date.isAfter(end)) {
            for (rite in MissalRite.entries) {
                val where = "$date/${rite.rawValue}"
                for (slug in hours) {
                    val h = try {
                        ContentStore.hourForDate(slug, date, rite)
                    } catch (t: Throwable) {
                        flag("$where/$slug: THREW ${t::class.simpleName}: ${t.message}")
                        continue
                    }
                    if (h == null) { flag("$where/$slug: returned null"); continue }
                    if (h.parts.isEmpty()) { flag("$where/$slug: zero parts"); continue }
                    runs++

                    for (p in h.parts) {
                        val texts = listOfNotNull(p.lat, p.latR, p.antiphonLat, p.eng, p.engR, p.antiphonEng, p.label, p.title)
                        for (t in texts) {
                            if (markup.containsMatchIn(t)) {
                                flag("$where/$slug: DO markup in ${p.type}/${p.variationKey}: ${t.take(80)}")
                                break
                            }
                        }
                        if ((p.type == "psalm" || p.type == "canticle") && p.verses.isNullOrEmpty()) {
                            flag("$where/$slug: ${p.type} ${p.label} (${p.ref}) has no verses")
                        }
                        if (p.type == "collect" && p.lat.isNullOrBlank()) flag("$where/$slug: empty collect ${p.variationKey}")
                        if (p.type == "hymn" && p.lat.isNullOrBlank()) flag("$where/$slug: empty hymn ${p.variationKey}")
                    }
                    // At most two hymns (a feast's proper doxology stanza may follow the hymn).
                    val hymns = h.parts.count { it.type == "hymn" }
                    if (slug != "matutinum" && hymns > 2) flag("$where/$slug: $hymns hymns")
                    // The day hours end with a conclusion or the office's own ending.
                    // (The Easter Vigil's Vespers of the older books, said within the Mass, have none.)
                    val vigilVespers = slug == "vesperae" && rite == MissalRite.PRE_1955 &&
                        h.parts.any { (it.label ?: "").contains("Sabbato Sancto") || (it.lat ?: "").startsWith("Véspere autem") }
                    if (slug in listOf("laudes", "vesperae") && !vigilVespers && h.parts.none { it.type == "collect" }) flag("$where/$slug: no collect")
                }
            }
            date = date.plusDays(1)
        }

        assertTrue("suspiciously few assemblies: $runs", runs > 9000)
        if (violations.isNotEmpty()) {
            throw AssertionError(
                "${violations.size} invariant violations (first 60):\n" +
                    violations.take(60).joinToString("\n"),
            )
        }
    }
}
