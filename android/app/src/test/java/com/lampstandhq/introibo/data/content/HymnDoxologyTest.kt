package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * The older books change the doxology of certain hymns with the feast or
 * season (Divinum Officium's `doxology`); the 1960 rubrics do not.
 */
class HymnDoxologyTest {

    private fun hymn(hour: String, date: LocalDate, rite: MissalRite): String {
        val assets = listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
        return ContentStore.hourForDate(hour, date, rite)!!.parts.first { it.type == "hymn" }.lat.orEmpty()
    }

    @Test
    fun feastsOfOurLadyAndChristmastideTakeTheNativityDoxology() {
        for (rite in listOf(MissalRite.RITE_1955, MissalRite.PRE_1955)) {
            val terce = hymn("tertia", LocalDate.of(2025, 12, 8), rite)
            assertTrue(terce, terce.startsWith("Nunc, Sancte, nobis, Spíritus"))
            assertTrue(terce, terce.contains("Jesu, tibi sit glória,\nQui natus es de Vírgine,\nCum Patre et almo Spíritu,"))
            assertFalse(terce, terce.contains("Præsta, Pater piíssime"))
            assertTrue(hymn("completorium", LocalDate.of(2025, 12, 27), rite).contains("Qui natus es de Vírgine"))
        }
    }

    @Test
    fun paschaltideTakesItsOwn() {
        val prime = hymn("prima", LocalDate.of(2026, 4, 20), MissalRite.PRE_1955)
        assertTrue(prime, prime.contains("Deo Patri sit glória,\nEt Fílio, qui a mórtuis\nSurréxit, ac Paráclito,"))
        assertTrue(prime, prime.endsWith("Amen."))
    }

    @Test
    fun the1960RubricsKeepTheHymnsOwnDoxology() {
        for (date in listOf(LocalDate.of(2025, 12, 8), LocalDate.of(2026, 4, 20))) {
            val terce = hymn("tertia", date, MissalRite.RITE_1962)
            assertTrue(terce, terce.contains("Præsta, Pater piíssime"))
        }
        // a per-annum feria in the older books too
        assertTrue(hymn("tertia", LocalDate.of(2026, 7, 7), MissalRite.PRE_1955).contains("Præsta, Pater piíssime"))
    }

    @Test
    fun elisionBracketsAreNotPrinted() {
        // Sacred Heart, Matins: DO writes "Cum Patr[e], et almo Spíritu"
        val h = hymn("matutinum", LocalDate.of(2026, 6, 12), MissalRite.RITE_1962)
        assertTrue(h, h.contains("Cum Patre, et almo Spíritu"))
        assertFalse(h, h.contains("["))
    }
}
