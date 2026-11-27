package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.MissalProperEntry
import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import kotlinx.serialization.json.Json
import java.time.LocalDate

/**
 * The Mass takes the season's form of a saint's chants as DO's getitem()
 * does: the Paschal Gradual in Eastertide, the Tract from Septuagesima, the
 * Commons' bracketed alleluias said only in Paschaltide, and a closing
 * alleluia left out from Septuagesima.
 */
class MassSeasonTest {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
    }

    private fun store() = ContentStore.initFromDirectory(assets)

    private val sanctoral: Map<String, MissalProperEntry> by lazy {
        Json { ignoreUnknownKeys = true }.decodeFromString(File(assets, "missal_sanctoral.json").readText())
    }

    @Test
    fun outsideEastertideTheBracketedAlleluiaIsLeftOut() {
        store()
        val m = ContentStore.properForDate(LocalDate.of(2024, 1, 15), MissalRite.RITE_1962)!!
        assertFalse(m.introit.lat, m.introit.lat.contains("Allelúja"))
        assertFalse(m.introit.eng, m.introit.eng.contains("(Alleluia"))
    }

    @Test
    fun inEastertideThePaschalGradualAndTheAlleluiasAreSaid() {
        store()
        val m = ContentStore.properForDate(LocalDate.of(2024, 4, 8), MissalRite.RITE_1962)!!
        val p = sanctoral["03-25"]!!.gradualeP!!
        assertEquals(MissalProperEntry.paschalAlleluia(p.lat, true), m.gradual!!.lat)
        assertTrue(m.introit.lat, m.introit.lat.contains("Allelúja, allelúja."))
        assertFalse(m.introit.lat, m.introit.lat.contains("(Allelúja"))
    }

    @Test
    fun fromSeptuagesimaTheTractIsSaid() {
        store()
        val m = ContentStore.properForDate(LocalDate.of(2024, 1, 29), MissalRite.RITE_1962)!!
        val t = sanctoral["01-29"]!!.tractus!!
        assertEquals(MissalProperEntry.lentenAlleluia(MissalProperEntry.paschalAlleluia(t.lat, false)), m.gradual!!.lat)
        assertEquals(null, m.tract)
    }

    @Test
    fun theClosingAlleluiaGoesFromSeptuagesima() {
        assertEquals("exaltatiónes Dei in fáucibus eórum.",
            MissalProperEntry.lentenAlleluia("exaltatiónes Dei in fáucibus eórum, allelúja."))
        assertEquals("Blessed be God!", MissalProperEntry.lentenAlleluia("Blessed be God! Alleluia."))
        assertEquals("Allelúja, allelúja.", MissalProperEntry.lentenAlleluia("Allelúja, allelúja."))
        assertEquals("benedíctus Deus.\nV. Sicut erat.",
            MissalProperEntry.lentenAlleluia("benedíctus Deus, allelúja.\nV. Sicut erat."))
    }
}
