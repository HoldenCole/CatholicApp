package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Matins reads the lessons and responsories Divinum Officium prints for the
 * day (office_lessons.json). Over the whole table, every day in every
 * book: the hour has exactly DO's lessons, each with DO's text, and a
 * responsory exactly where DO prints one.
 */
class MatinsDoLessonsTest {

    private fun init() {
        val assets = listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
    }

    @Test
    fun everyLessonAndResponsoryIsDivinumOfficiums() {
        init()
        val table = ContentStore.officeLessons()
        assertTrue("lesson table is empty", table.texts.size > 4000)
        val problems = ArrayList<String>()
        var checked = 0
        for (rite in MissalRite.entries) {
            val days = table.days[rite.rawValue] ?: error("no lessons for ${rite.rawValue}")
            assertTrue("${rite.rawValue}: ${days.size} days", days.size >= 2557)
            var d = LocalDate.of(2024, 1, 1)
            while (d.year <= 2030) {
                val row = days[d.toString()] ?: error("no row for $rite $d")
                val parts = ContentStore.hourForDate("matutinum", d, rite)!!.parts
                val lessons = parts.filter { Regex("^lectio[1-9]$").matches(it.variationKey ?: "") }
                if (lessons.size != row.size) problems += "$rite $d: ${lessons.size} lessons, DO ${row.size}"
                for ((k, pair) in row.withIndex()) {
                    val l = parts.firstOrNull { it.variationKey == "lectio${k + 1}" }
                    if (pair[0] >= 0 && l?.lat != table.texts[pair[0]].lat) problems += "$rite $d: lectio${k + 1} is not DO's"
                    val r = parts.firstOrNull { it.variationKey == "responsory${k + 1}" }
                    if ((r != null) != (pair[1] >= 0)) problems += "$rite $d: responsory${k + 1} ${if (r != null) "present" else "missing"}, DO index ${pair[1]}"
                    else if (r != null && r.lat.orEmpty().substringBefore("\n") != table.texts[pair[1]].lat.substringBefore("\n")) problems += "$rite $d: responsory${k + 1} is not DO's"
                }
                checked++
                d = d.plusDays(1)
            }
        }
        assertTrue("checked $checked", checked == 3 * 2557)
        assertEquals("${problems.size} problems, e.g. ${problems.take(12)}", 0, problems.size)
    }

    @Test
    fun homilyOfTheCommonAndScriptureResponsories() {
        init()
        // St Callistus (14 Oct 2026) in the 1955 books: the Scripture's own
        // responsory in the first nocturn and the Common's homily in the third,
        // where the template's filler used to stand.
        val m = ContentStore.hourForDate("matutinum", LocalDate.of(2026, 10, 14), MissalRite.RITE_1955)!!.parts
        fun lat(vk: String) = m.first { it.variationKey == vk }.lat.orEmpty()
        assertTrue(lat("responsory1"), lat("responsory1").startsWith("℟. Refúlsit sol in clípeos áureos"))
        assertTrue(lat("lectio7"), lat("lectio7").contains("Homilía sancti Leónis Papæ"))
        assertTrue(lat("lectio9"), lat("lectio9").startsWith("Cum ergo cohortatiónes nostras"))
        // Tenebrae: a responsory after every lesson.
        val t = ContentStore.hourForDate("matutinum", LocalDate.of(2027, 3, 25), MissalRite.RITE_1962)!!.parts
        assertEquals(9, t.count { Regex("^responsory[1-9]$").matches(it.variationKey ?: "") })
        assertTrue(t.first { it.variationKey == "responsory1" }.lat.orEmpty().startsWith("℟. In monte Olivéti"))
    }
}
