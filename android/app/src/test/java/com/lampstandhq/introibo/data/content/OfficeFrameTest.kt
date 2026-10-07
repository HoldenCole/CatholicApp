package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * The fixed frame of the hours as Divinum Officium prints it (OfficeFrame):
 * Glória Patri after the psalms, the collect's Orémus and conclusion, the
 * Pater/Ave/Credo of the older books only, the ends of the hours, the
 * invitatory inside the Venite, the absolution and blessings by weekday.
 */
class OfficeFrameTest {

    private fun store() {
        val assets = listOf("src/main/assets", "app/src/main/assets").map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
    }

    private fun hour(slug: String, date: LocalDate, rite: MissalRite) = ContentStore.hourForDate(slug, date, rite)!!
    private fun lats(h: Hour) = h.parts.flatMap { p -> listOfNotNull(p.lat, p.latR) + (p.verses?.map { it.lat } ?: emptyList()) }

    @Test
    fun gloriaPatriFollowsEveryPsalmAndTheOpeningIsWhole() {
        store()
        val lauds = hour("laudes", LocalDate.of(2025, 12, 1), MissalRite.RITE_1962)
        for (p in lauds.parts.filter { it.type == "psalm" || it.type == "canticle" }) {
            assertTrue("${p.label} should end with Sicut erat", p.verses!!.last().lat.startsWith("Sicut erat"))
        }
        val opening = lauds.parts.first { it.type == "vr" && (it.lat ?: "").contains("Deus, in adjutórium") }
        assertTrue(opening.latR!!.contains("Sicut erat") && opening.latR!!.endsWith("Allelúja."))
        // Septuagesima to Holy Week: Laus tibi instead of the Allelúja
        val sept = hour("laudes", LocalDate.of(2026, 2, 3), MissalRite.RITE_1962)
        assertTrue(sept.parts.first { it.type == "vr" && (it.lat ?: "").contains("Deus, in adjutórium") }.latR!!.endsWith("Rex ætérnæ glóriæ."))
        // the Benedicite carries no Glória Patri
        val sunday = hour("laudes", LocalDate.of(2026, 1, 18), MissalRite.RITE_1962)
        val bened = sunday.parts.first { (it.label ?: "").contains("Trium Puer") || it.verses?.firstOrNull()?.lat?.startsWith("Benedícite, ómnia") == true }
        assertFalse(bened.verses!!.last().lat.startsWith("Sicut erat"))
    }

    @Test
    fun collectsHaveOremusConclusionAndAmen() {
        store()
        val lauds = hour("laudes", LocalDate.of(2025, 12, 1), MissalRite.RITE_1962)
        val ci = lauds.parts.indexOfFirst { it.variationKey == "oratio" }
        assertEquals("Orémus.", lauds.parts[ci - 1].label)
        assertTrue(lauds.parts[ci - 2].lat!!.startsWith("℣. Dómine, exáudi"))
        val collect = lauds.parts[ci].lat!!
        assertTrue(collect, collect.contains("Qui vivis et regnas") && collect.endsWith("℟. Amen."))
        // a run of commemorations: one conclusion, after the last
        val dec4 = hour("laudes", LocalDate.of(2025, 12, 4), MissalRite.RITE_1962)
        val cs = dec4.parts.filter { it.type == "collect" }
        assertEquals(3, cs.size)
        assertTrue(cs[0].lat!!.contains("Per Dóminum"))
        assertFalse(cs[1].lat!!.contains("℟. Amen."))
        assertTrue(cs[2].lat!!.contains("Per Dóminum") && cs[2].lat!!.endsWith("℟. Amen."))
        val capitulum = lauds.parts.first { it.type == "capitulum" }
        assertTrue(capitulum.lat!!.endsWith("℟. Deo grátias."))
    }

    @Test
    fun paterAveCredoOnlyInTheOlderBooks() {
        store()
        val d = LocalDate.of(2025, 12, 1)
        for (slug in listOf("laudes", "prima", "tertia", "vesperae")) {
            assertFalse(hour(slug, d, MissalRite.RITE_1962).parts.any { it.type == "pater" && (it.label ?: "").contains("Ave") })
            assertFalse(hour(slug, d, MissalRite.RITE_1955).parts.any { it.type == "pater" && (it.label ?: "").contains("Ave") })
            val old = hour(slug, d, MissalRite.PRE_1955).parts.first { it.type == "pater" }
            assertTrue(old.label!!.contains("Ave María"))
            assertEquals(slug == "prima", old.lat!!.contains("Credo in Deum"))
        }
        val matins = hour("matutinum", d, MissalRite.PRE_1955)
        assertTrue(matins.parts[0].type == "pater" && matins.parts[0].lat!!.contains("Credo in Deum"))
        assertFalse(hour("matutinum", d, MissalRite.RITE_1962).parts.any { it.type == "pater" && (it.label ?: "").contains("Ave") })
        // the Pater of the nocturn is said secreto up to Et ne nos indúcas; none before the collect
        val m62 = hour("matutinum", d, MissalRite.RITE_1962)
        val paters = m62.parts.filter { it.type == "pater" }
        assertEquals(1, paters.size)
        assertTrue(paters[0].lat!!.endsWith("℟. Sed líbera nos a malo."))
    }

    @Test
    fun endsOfTheHours() {
        store()
        val d = LocalDate.of(2025, 12, 1)
        val terce = hour("tertia", d, MissalRite.RITE_1962)
        assertTrue(terce.parts.last().lat!!.startsWith("℣. Fidélium ánimæ"))
        val prime = hour("prima", d, MissalRite.RITE_1962)
        val bi = prime.parts.indexOfFirst { it.variationKey == "prima2.benedictio2" }
        assertTrue(prime.parts[bi - 1].lat!!.startsWith("℣. Benedícite."))
        assertTrue(prime.parts[bi].lat!!.contains("Et fidélium ánimæ") && prime.parts[bi].lat!!.endsWith("℟. Amen."))
        val compline = hour("completorium", d, MissalRite.RITE_1962)
        val l = lats(compline)
        assertTrue(l.any { it.startsWith("℣. Adjutórium nostrum") })
        assertTrue(l.any { it.startsWith("Benedíctio. Benedícat et custódiat") })
        assertTrue(l.any { it.startsWith("℣. Divínum auxílium") })
        assertFalse(compline.parts.any { (it.label ?: "").contains("Ave María") })
        val old = hour("completorium", d, MissalRite.PRE_1955)
        assertTrue(old.parts.last().lat!!.contains("Credo in Deum"))
        val resp = compline.parts.first { it.type == "responsory" }.lat!!.split("\n")
        assertTrue(resp[0].startsWith("℟.br. In manus tuas") && resp[1].startsWith("℟. In manus tuas"))
    }

    @Test
    fun invitatoryIsWovenIntoTheVenite() {
        store()
        val m = hour("matutinum", LocalDate.of(2025, 12, 1), MissalRite.RITE_1962)
        val venite = m.parts.first { it.variationKey == "matutinum.psalm1" }.verses!!.map { it.lat }
        assertEquals("Ant. Regem ventúrum Dóminum, Veníte, adorémus.", venite[0])   // intoned, then said whole
        assertEquals("Ant. Regem ventúrum Dóminum, Veníte, adorémus.", venite[3])
        assertEquals("Ant. Veníte, adorémus.", venite[6])
        assertTrue(venite[venite.size - 4].startsWith("℣. Glória Patri"))
        assertEquals("Ant. Regem ventúrum Dóminum, Veníte, adorémus.", venite.last())
    }

    @Test
    fun absolutionAndBlessingsFollowTheWeekdayOnFerias() {
        store()
        fun abs(date: LocalDate) = hour("matutinum", date, MissalRite.RITE_1962).parts.first { it.label == "Absolutio" }.lat!!.take(8)
        fun bless(date: LocalDate) = hour("matutinum", date, MissalRite.RITE_1962).parts.filter { (it.label ?: "").startsWith("Blessing before") }.map { it.lat!!.take(12) }
        assertEquals("Exáudi, ", abs(LocalDate.of(2025, 12, 1)))   // Monday
        assertEquals("Ipsíus p", abs(LocalDate.of(2025, 12, 2)))   // Tuesday
        assertEquals("A víncul", abs(LocalDate.of(2025, 12, 3)))   // Ember-free Wednesday of Advent I
        assertEquals(listOf("Deus Pater o", "Christus per", "Ignem sui am"), bless(LocalDate.of(2025, 12, 9)))   // Tuesday feria
        // a saint's feast with three lessons: the third nocturn's set with the saint's own second blessing
        assertEquals(listOf("Ille nos ben", "Cujus festum", "Ad societáte"), bless(LocalDate.of(2025, 12, 2)))   // S. Bibiana
        assertEquals("Quorum festu", bless(LocalDate.of(2026, 1, 20))[1])   // Ss. Fabian and Sebastian
        // Sunday with three lessons: the Gospel's words at the third blessing
        assertEquals("Per evangéli", bless(LocalDate.of(2025, 12, 7))[2])
        // the vigil of a feast / an Ember day: the homily's blessing first
        assertEquals("Evangélica l", bless(LocalDate.of(2025, 12, 17))[0])
    }

    @Test
    fun ferialPrecesCarryNoPsalm() {
        store()
        val lauds = hour("laudes", LocalDate.of(2025, 12, 12), MissalRite.RITE_1962)
        val preces = lauds.parts.filter { it.type == "preces" }
        assertTrue(preces.isNotEmpty())
        assertFalse(preces.any { (it.label ?: "").startsWith("Psalmus") })
        assertTrue(preces.last().verses!!.last().lat.startsWith("℣. Dómine, exáudi"))
        assertTrue(preces.any { p -> p.verses?.any { it.lat.startsWith("℣. Dómine, salvum fac regem") } == true })
    }
}
