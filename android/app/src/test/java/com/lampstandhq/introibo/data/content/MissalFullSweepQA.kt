package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Full-corpus QA sweep of the MISSAL: every day of a complete liturgical
 * cycle (Advent 2025 – Dec 2026), all three rites, through the real
 * properForDate resolution (winner formulary, redirects, commune
 * inheritance, preceding-Sunday fallbacks).
 *
 * Invariants: a Mass exists for every day; its core texts are non-empty;
 * no raw DivinumOfficium markup leaks into any rendered field.
 */
class MissalFullSweepQA {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory } ?: error("cannot locate assets dir")
    }

    private val markup = Regex("""^\[[A-Z][^\]]{2,40}\]|\(rubrica |@[A-Za-z]+/[A-Za-z0-9-]+:|(?<!\p{L}):s/""")

    @Test
    fun fullCycleMissalInvariants() {
        ContentStore.initFromDirectory(assets)
        val violations = mutableListOf<String>()
        fun flag(msg: String) { if (violations.size < 200) violations.add(msg) }

        var date = LocalDate.of(2025, 11, 29)
        val end = LocalDate.of(2026, 12, 31)
        var runs = 0
        while (!date.isAfter(end)) {
            for (rite in MissalRite.entries) {
                val where = "$date/${rite.rawValue}"
                val proper = ContentStore.properForDate(date, rite)
                if (proper == null) {
                    flag("$where: no Mass resolved")
                } else {
                    runs++
                    val core = mapOf(
                        "introit" to proper.introit.lat,
                        "collect" to proper.collect.lat,
                        "epistle" to proper.epistle.lat,
                        "gospel" to proper.gospel.lat,
                        "introit-eng" to proper.introit.eng,
                        "collect-eng" to proper.collect.eng,
                    )
                    for ((name, text) in core) {
                        if (text.isBlank()) flag("$where: empty $name")
                        else if (markup.containsMatchIn(text)) {
                            flag("$where: markup leak in $name: ${text.take(60)}")
                        }
                    }
                }
            }
            date = date.plusDays(1)
        }

        assertTrue("suspiciously few Masses resolved: $runs", runs > 1150)
        if (violations.isNotEmpty()) {
            throw AssertionError(
                "${violations.size} Missal invariant violations (first 60):\n" +
                    violations.take(60).joinToString("\n"),
            )
        }
    }
}
