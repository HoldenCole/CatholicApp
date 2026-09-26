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
 * Antiphon placement after Divinum Officium's antetpsalm: the antiphon is
 * repeated whole after the last psalm it covers; the older books intone only
 * the incipit before the psalm below double rank, the 1960 books double all.
 */
class AntiphonPlacementTest {

    private fun psalm(vk: String, ant: String? = null) = Hour.Part(type = "psalm", label = "Psalmus", variationKey = vk, antiphonLat = ant, antiphonEng = ant?.let { "EN $it" })
    private fun ant(vk: String?, lat: String) = Hour.Part(type = "antiphon", label = "Antiphon", variationKey = vk, lat = lat, eng = "EN $lat")

    @Test
    fun incipitAndWholeForms() {
        assertEquals("Dele iniquitátem meam.", AntiphonPlacement.intoned("Dele iniquitátem meam, * et lava me."))
        assertEquals("Cantáte Dómino", AntiphonPlacement.intoned("Cantáte Dómino * cánticum novum."))
        assertEquals("Allelúja, allelúja.", AntiphonPlacement.intoned("Allelúja, allelúja."))
        assertEquals("Dele iniquitátem meam, et lava me.", AntiphonPlacement.whole("Dele iniquitátem meam, * et lava me."))
    }

    @Test
    fun runsAndRepeats() {
        val parts = listOf(
            Hour.Part(type = "vr", lat = "Deus, in adjutórium"),
            ant("invit", "Regem Apostolórum Dóminum, * Veníte, adorémus."),
            psalm("matutinum.psalm1"),
            psalm("laudes.psalm1", "Miserére * mei, Deus."),
            psalm("laudes.psalm2"),
            psalm("laudes.canticle1"),
            Hour.Part(type = "capitulum", lat = "Fratres"),
            ant("ant_tertia", "Sapiéntia * ædificávit sibi domum."),
            psalm("tertia.psalm1"), psalm("tertia.psalm2"), psalm("tertia.psalm3"),
            Hour.Part(type = "hymn", lat = "Nunc, Sancte"),
            ant(null, "Allelúja, Allelúja, Allelúja."),
            psalm("x"),
            ant(null, "Allelúja, Allelúja, Allelúja."),
            Hour.Part(type = "heading", lat = "Commemoratio"),
            ant(null, "Ecce sacérdos * magnus."),
            Hour.Part(type = "vr", lat = "℣. Amávit eum"),
        )
        val rep = AntiphonPlacement.repeats(parts)
        // The invitatory never repeats after the Venite; a commemoration antiphon has no psalm.
        assertNull(rep[2]); assertNull(rep[16])
        // One antiphon over a run of psalms repeats after the last of them, asterisk dropped.
        assertEquals("Miserére mei, Deus." to "EN Miserére mei, Deus.", rep[5])
        assertNull(rep[3]); assertNull(rep[4])
        assertEquals("Sapiéntia ædificávit sibi domum.", rep[10]?.first)
        assertNull(rep[8])
        // A Special script that already prints the antiphon after the psalm is left alone.
        assertNull(rep[13])
        assertEquals(2, rep.size)
    }

    @Test
    fun olderBooksIntoneBelowDoubleRankAndTheLittleHoursAlways() {
        val assets = listOf("src/main/assets", "app/src/main/assets").map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
        // A Lenten feria (Divino Afflatu): Lauds antiphons intoned, Benedictus antiphon too.
        val feria = LocalDate.of(2026, 3, 3)
        val laudes = ContentStore.hourForDate("laudes", feria, MissalRite.PRE_1955)!!
        val ps = laudes.parts.first { it.variationKey == "laudes.psalm1" }
        assertTrue("ferial Lauds psalm antiphon should be intoned", ps.antiphonIntoned == true)
        assertTrue(laudes.parts.first { it.variationKey == "ant_laudes" }.antiphonIntoned == true)
        // The same day in 1962: every antiphon doubled.
        val laudes62 = ContentStore.hourForDate("laudes", feria, MissalRite.RITE_1962)!!
        assertFalse(laudes62.parts.any { it.antiphonIntoned == true })
        // A double (the Annunciation): Lauds doubled; Terce still intoned in the older books.
        val annunc = LocalDate.of(2026, 3, 25)
        val laudesD = ContentStore.hourForDate("laudes", annunc, MissalRite.PRE_1955)!!
        assertFalse(laudesD.parts.any { it.antiphonIntoned == true })
        val tertia = ContentStore.hourForDate("tertia", annunc, MissalRite.PRE_1955)!!
        assertTrue(tertia.parts.first { it.variationKey == "ant_tertia" }.antiphonIntoned == true)
        // The O antiphon at Vespers is doubled even on the Advent feria.
        val vespO = ContentStore.hourForDate("vesperae", LocalDate.of(2025, 12, 18), MissalRite.PRE_1955)!!
        assertNull(vespO.parts.first { it.variationKey == "ant_vespera" }.antiphonIntoned)
        assertTrue(vespO.parts.first { it.variationKey == "vesperae.psalm1" }.antiphonIntoned == true)
        // Every hour repeats its antiphons after the psalms.
        assertTrue(AntiphonPlacement.repeats(laudes.parts).isNotEmpty())
        assertTrue(AntiphonPlacement.repeats(tertia.parts).isNotEmpty())
    }
}
