package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * August to November: Matins reads the Scripture occurrens from Divinum
 * Officium's month-week files ("083-2"), so Lectio I and II change day by
 * day instead of sitting on the template's Genesis.
 */
class MatinsMonthdayScriptureTest {

    private fun init() {
        val assets = listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
    }

    private fun lectio(date: LocalDate, rite: MissalRite, n: Int): String {
        val m = ContentStore.hourForDate("matutinum", date, rite)!!
        return m.parts.first { it.variationKey == "lectio$n" }.lat.orEmpty()
    }

    @Test
    fun monthdayKeyMatchesDivinumOfficiumsSundayNames() {
        init()
        val roman = mapOf("I" to 1, "II" to 2, "III" to 3, "IV" to 4, "V" to 5)
        val months = mapOf("Augusti" to 8, "Septembris" to 9, "Octobris" to 10, "Novembris" to 11)
        val re = Regex("\\b(I|II|III|IV|V)\\. (Augusti|Septembris|Octobris|Novembris)\\b")
        var checked = 0
        for (rite in listOf(MissalRite.RITE_1962, MissalRite.RITE_1955, MissalRite.PRE_1955)) {
            for (year in 2024..2030) {
                var d = LocalDate.of(year, 8, 1)
                while (d.monthValue <= 11) {
                    val name = ContentStore.ordoForDate(d, rite)?.name ?: ""
                    re.find(name)?.let { mt ->
                        val want = "%02d%d-%d".format(months.getValue(mt.groupValues[2]), roman.getValue(mt.groupValues[1]), d.dayOfWeek.value % 7)
                        assertEquals("$rite $d '$name'", want, OfficeAssembler.monthdayKey(d, rite))
                        checked++
                    }
                    d = d.plusDays(1)
                }
            }
        }
        assertTrue("expected many named days, got $checked", checked > 200)
    }

    @Test
    fun feriaReadsTheMonthsBook() {
        init()
        // Tuesday of the third week of August 2026 (083-2): Wisdom.
        lectio(LocalDate.of(2026, 8, 18), MissalRite.RITE_1962, 1).let { assertTrue(it, it.startsWith("De libro Sapiéntiæ")) }
        // Wednesday 4 Nov 2026 is St Charles (III class): the feria's Scripture
        // (Ezekiel, first week of November) stays as Lectio I.
        lectio(LocalDate.of(2026, 11, 4), MissalRite.RITE_1962, 1).let { assertTrue(it, it.startsWith("De Ezechiéle")) }
        // Monday of the second week of October (102-1): Maccabees, in every book.
        for (rite in MissalRite.entries) {
            lectio(LocalDate.of(2026, 10, 12), rite, 1).let { assertTrue("$rite: $it", it.startsWith("De libro primo Machab")) }
        }
        // Never the template's Genesis outside Septuagesima.
        for (rite in MissalRite.entries) {
            assertTrue("$rite", !lectio(LocalDate.of(2026, 9, 23), rite, 1).contains("In princípio creávit"))
        }
    }

    @Test
    fun resumedSundayInNovemberReadsDanielNotTimothy() {
        init()
        // 8 Nov 2026: Dominica V post Epiphaniam resumed, III. Novembris (113-0).
        val l1 = lectio(LocalDate.of(2026, 11, 8), MissalRite.RITE_1962, 1)
        assertTrue(l1, l1.startsWith("Incipit liber Daniélis"))
        // Its third-nocturn homily still comes from the Sunday's own file.
        val m = ContentStore.hourForDate("matutinum", LocalDate.of(2026, 11, 8), MissalRite.RITE_1955)!!
        val l7 = m.parts.first { it.variationKey == "lectio7" }.lat.orEmpty()
        assertTrue(l7, l7.isNotBlank() && !l7.contains("Daniélis"))
    }
}
