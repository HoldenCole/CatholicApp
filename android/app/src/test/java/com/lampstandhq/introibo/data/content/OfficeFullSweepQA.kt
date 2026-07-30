package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Full-corpus QA sweep of the Divine Office: every canonical hour, every day
 * of a complete liturgical cycle (Advent 2025 – Dec 2026), all three rites,
 * through the REAL ContentStore pipeline (assembly + proper layers +
 * commemorations) via the initFromDirectory test seam.
 *
 * Checks structural invariants only — content correctness is pinned by
 * OfficeStructureFixTest; this sweep catches the day/rite combinations
 * nobody thought to look at.
 */
class OfficeFullSweepQA {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory }
            ?: error("cannot locate assets dir")
    }

    private val dayHours = listOf("matutinum", "laudes", "tertia", "sexta", "nona", "vesperae")

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
                val ordo = ContentStore.ordoForDate(date, rite)
                val temporalKey = ordo?.temporal
                val isTenebrae = temporalKey in setOf("quad6-4", "quad6-5", "quad6-6")
                val where = "$date/${rite.rawValue}"

                for (slug in dayHours + listOf("prima", "completorium")) {
                    val h = try {
                        ContentStore.hourForDate(slug, date, rite)
                    } catch (t: Throwable) {
                        flag("$where/$slug: THREW ${t::class.simpleName}: ${t.message}")
                        continue
                    }
                    if (h == null) { flag("$where/$slug: returned null"); continue }
                    if (h.parts.isEmpty()) { flag("$where/$slug: zero parts"); continue }
                    runs++

                    val collects = h.parts.filter { it.type == "collect" }
                    when (slug) {
                        "prima" -> {
                            if (collects.none { it.lat.orEmpty().startsWith("Dómine Deus omnípotens") }) {
                                flag("$where/prima: invariable collect replaced or missing")
                            }
                        }
                        "completorium" -> {
                            if (collects.none { it.lat.orEmpty().startsWith("Vísita") }) {
                                flag("$where/completorium: invariable collect replaced or missing")
                            }
                        }
                        else -> {
                            val day = collects.filter { it.variationKey == "oratio" }
                            if (day.size != 1) {
                                flag("$where/$slug: expected 1 day collect, got ${day.size}")
                            }
                            day.firstOrNull()?.let { c ->
                                if (c.lat.isNullOrBlank()) flag("$where/$slug: empty day collect")
                                if (c.lat.orEmpty().startsWith("Dómine Deus omnípotens, qui ad princípium")) {
                                    flag("$where/$slug: day collect is Prime's fixed collect")
                                }
                            }
                        }
                    }

                    // No responsorium breve at Lauds or Vespers, ever.
                    if (slug == "laudes" || slug == "vesperae") {
                        if (h.parts.any { (it.label ?: "").contains("Responsorium Breve") }) {
                            flag("$where/$slug: responsorium breve present")
                        }
                        // Exactly one hymn — a feast's PROPER DOXOLOGY stanza
                        // legitimately overrides the doxology slot as a
                        // second hymn-typed part.
                        val hymns = h.parts.count {
                            it.type == "hymn" && it.variationKey != "doxology"
                        }
                        if (hymns != 1) flag("$where/$slug: expected 1 hymn, got $hymns")
                    }

                    // Canticle-antiphon slots must hold ONE antiphon, not a
                    // psalm-antiphon list.
                    for (vk in listOf("ant_laudes", "ant_vespera")) {
                        h.parts.firstOrNull { it.variationKey == vk }?.let { ant ->
                            val lines = ant.lat.orEmpty().split("\n").count { it.isNotBlank() }
                            if (lines >= 4) flag("$where/$slug: $vk holds a $lines-line list")
                            if (ant.lat.isNullOrBlank()) flag("$where/$slug: $vk empty")
                        }
                    }

                    // Psalmody counts per hour.
                    val psalms = h.parts.count { it.type == "psalm" }
                    val expected: IntRange? = when (slug) {
                        "matutinum" -> if (isTenebrae) 9..10 else 10..10
                        "laudes" -> 4..4
                        "vesperae" -> 5..5
                        "tertia", "sexta", "nona" -> 3..3
                        "prima" -> 3..4
                        "completorium" -> 3..3
                        else -> null
                    }
                    if (expected != null && psalms !in expected) {
                        flag("$where/$slug: $psalms psalms (expected $expected)")
                    }

                    // Matins lesson counts follow the nocturn structure.
                    if (slug == "matutinum") {
                        val readings = h.parts.count { it.type == "reading" }
                        if (readings != 3 && readings != 9) {
                            flag("$where/matutinum: $readings lessons (expected 3 or 9)")
                        }
                        if (!isTenebrae && h.parts.none { it.type == "hymn" }) {
                            flag("$where/matutinum: hymn missing")
                        }
                    }

                    // Versicle slots stay populated.
                    if (slug == "laudes" && h.parts.none { it.variationKey == "versum_1" }) {
                        flag("$where/laudes: versicle missing")
                    }
                    if (slug == "vesperae" && h.parts.none { it.variationKey == "versum_2" }) {
                        flag("$where/vesperae: versicle missing")
                    }
                }

                // A sanctoral winner's own collect must actually land.
                if (ordo != null && ordo.winner == "sanctoral") {
                    val saintOratios = ContentStore.sanctoralOratioForQA(ordo.winnerKey, rite)
                    if (saintOratios != null) {
                        val vespers = ContentStore.hourForDate("vesperae", date, rite)
                        val got = vespers?.parts
                            ?.firstOrNull { it.variationKey == "oratio" && it.type == "collect" }
                            ?.lat
                        if (got != null && got !in saintOratios) {
                            flag("$where: saint's collect did not land at Vespers " +
                                "(got ${got.take(40)}…)")
                        }
                    }
                }

                // Commemorations render at Lauds when the data supports them.
                val commem = ordo?.commemoration
                if (!commem.isNullOrEmpty() && ContentStore.commemorationHasOratioForQA(commem)) {
                    val lauds = ContentStore.hourForDate("laudes", date, rite)
                    if (lauds != null &&
                        lauds.parts.none { it.type == "heading" && it.label == "Commemoratio" }
                    ) {
                        flag("$where: commemoration $commem missing at Lauds")
                    }
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
