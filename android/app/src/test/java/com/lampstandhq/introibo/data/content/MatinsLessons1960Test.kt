package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * The lessons and responsories of a one-nocturn Matins under the 1960
 * rubrics, as Divinum Officium chooses them: the Sunday's lessons 1, 2+3 and
 * the Gospel homily with responsories 1, 3 (and 9 in Advent/Lent); the
 * III-class feast's Scripture lessons (2+3 as one) with the Scripture's
 * responsories 1 and 3 and the saint's legend; the Te Deum in place of the
 * last responsory. Expectations are DO's own text for the dates.
 */
class MatinsLessons1960Test {
    // (also: the older books' Matins lessons follow the office Divinum Officium's precedence chose)

    private fun store() {
        val assets = listOf("src/main/assets", "app/src/main/assets").map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
    }

    private fun matins(date: LocalDate, rite: MissalRite = MissalRite.RITE_1962) = ContentStore.hourForDate("matutinum", date, rite)!!
    private fun part(h: Hour, vk: String) = h.parts.firstOrNull { it.variationKey == vk }
    private fun hasTeDeum(h: Hour) = h.parts.any { it.type == "canticle" && (it.label ?: "").contains("Te Deum") }

    @Test
    fun adventSundayReadsTheHomilyWithResponsoriesOneThreeAndNine() {
        store()
        val h = matins(LocalDate.of(2025, 11, 30))
        val l2 = part(h, "lectio2")!!.lat!!
        assertTrue(l2, l2.contains("Væ genti peccatríci") && l2.contains("Terra vestra desérta"))
        assertTrue(part(h, "lectio3")!!.lat!!.startsWith("Léctio sancti Evangélii secúndum Lucam"))
        assertTrue(part(h, "responsory1")!!.lat!!.startsWith("R. Aspíciens a longe"))
        assertTrue(part(h, "responsory2")!!.lat!!.startsWith("R. Missus est Gábriel"))
        assertTrue(part(h, "responsory3")!!.lat!!.startsWith("R. Ecce dies véniunt"))
        assertFalse(hasTeDeum(h))
    }

    @Test
    fun sundayPerAnnumReadsTheHomilyAndTheTeDeumStandsForTheThirdResponsory() {
        store()
        val h = matins(LocalDate.of(2026, 7, 5))
        assertTrue(part(h, "lectio3")!!.lat!!.startsWith("Léctio sancti Evangélii secúndum Marcum"))
        assertTrue(part(h, "responsory2")!!.lat!!.startsWith("R. Dóminus, qui erípuit me"))
        assertNull(part(h, "responsory3"))
        assertTrue(hasTeDeum(h))
        // the responsory before the Te Deum closes with the Glória Patri
        val r2 = part(h, "responsory2")!!.lat!!
        assertTrue(r2, r2.contains("℣. Glória Patri"))
    }

    @Test
    fun thirdClassFeastReadsTheScriptureWithItsResponsoriesAndTheLegend() {
        store()
        // S. Bibianæ, Tuesday of Advent I: Isa 2:1-3, Isa 2:4-9, the legend
        val h = matins(LocalDate.of(2025, 12, 2))
        assertTrue(part(h, "lectio1")!!.lat!!.contains("Verbum, quod vidit Isaías"))
        val l2 = part(h, "lectio2")!!.lat!!
        assertTrue(l2, l2.contains("Et judicábit gentes") && l2.contains("Repléta est terra argénto"))
        assertTrue(part(h, "lectio3")!!.lat!!.startsWith("Bibiána virgo Romána"))
        assertTrue(part(h, "responsory1")!!.lat!!.startsWith("R. Montes Israël"))
        assertTrue(part(h, "responsory2")!!.lat!!.startsWith("R. Ecce ab Austro"))
        assertNull(part(h, "responsory3"))
        assertTrue(hasTeDeum(h))
        // S. Nicolai (vide Commune): the feria's responsories, not the Common's
        val nic = matins(LocalDate.of(2025, 12, 6))
        assertTrue(part(nic, "responsory1")!!.lat!!.startsWith("R. Ecce virgo concípiet"))
        assertTrue(part(nic, "responsory2")!!.lat!!.startsWith("R. Ecce dies véniunt"))
    }

    @Test
    fun olderBooksReadTheLessonsOfTheOfficeDivinumOfficiumChose() {
        store()
        // pre-1955: St Andrew, impeded by Advent Sunday, is kept on Dec 1 (the app's calendar has the feria)
        val andrew = matins(LocalDate.of(2025, 12, 1), MissalRite.PRE_1955)
        assertTrue(part(andrew, "lectio4")!!.lat!!.startsWith("Andréas Apóstolus"))
        assertTrue(part(andrew, "lectio1")!!.lat!!.contains("Finis legis, Christus"))
        // pre-1955: St Damasus (semidouble) outranks the Advent feria; his legend, not the template's filler
        val damasus = matins(LocalDate.of(2025, 12, 11), MissalRite.PRE_1955)
        assertTrue(part(damasus, "lectio4")!!.lat!!.startsWith("Dámasus Hispánus"))
        // 1955: St Bibiana is a commemoration; the feria's third Scripture lesson is read
        val feria = matins(LocalDate.of(2025, 12, 2), MissalRite.RITE_1955)
        assertTrue(part(feria, "lectio3")!!.lat!!.contains("Repléta est terra argénto"))
        // a Common's variant (C5-1, C4b) layers over its Common: the second and third nocturns' responsories
        val xavier = matins(LocalDate.of(2025, 12, 3), MissalRite.PRE_1955)
        assertTrue(part(xavier, "responsory4")!!.lat!!.startsWith("R. Honéstum fecit illum"))
        assertTrue(part(damasus, "responsory4")!!.lat!!.startsWith("R. Invéni David"))
    }

    @Test
    fun feriaKeepsItsThreeResponsoriesWithoutTeDeum() {
        store()
        val h = matins(LocalDate.of(2025, 12, 1))
        assertEquals(3, h.parts.count { (it.variationKey ?: "").matches(Regex("responsory[1-3]")) })
        assertFalse(hasTeDeum(h))
    }
}
