package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** Holy Name Sunday (2026-01-04, 1962): right Mass and office after the
 *  01-00 rekey (it previously served the Circumcision Mass). */
class HolyNameSpotCheck {
    @Test
    fun holyNameSundayServesItsOwnMassAndOffice() {
        val assets = listOf("src/main/assets", "app/src/main/assets")
            .map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
        val date = LocalDate.of(2026, 1, 4)
        val mass = ContentStore.properForDate(date, MissalRite.RITE_1962)!!
        assertTrue("introit should be In nomine Jesu, got ${mass.introit.lat.take(40)}",
            mass.introit.lat.startsWith("In nómine Jesu"))
        val vespers = ContentStore.hourForDate("vesperae", date, MissalRite.RITE_1962)!!
        val collect = vespers.parts.first { it.variationKey == "oratio" && it.type == "collect" }
        assertTrue("office collect should be Deus qui unigenitum, got ${collect.lat?.take(40)}",
            collect.lat.orEmpty().startsWith("Deus, qui unigénitum"))
        // Jan 5 feria must still serve Puer natus, not Holy Name.
        val jan5 = ContentStore.properForDate(LocalDate.of(2026, 1, 5), MissalRite.RITE_1962)!!
        assertTrue("Jan 5 Mass should be Puer natus, got ${jan5.introit.lat.take(40)}",
            jan5.introit.lat.startsWith("Puer natus"))
    }
}
