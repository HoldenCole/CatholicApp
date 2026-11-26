package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.VernacularLanguage
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * The French overlay (french-translation/, ported from Divinum Officium's
 * French): it is read through the Spanish overlay schemas by its own file
 * names, lands on the Office, the psalter, the Mass and the calendar, leaves
 * the Latin alone, and gives the English back on the switch.
 */
class FrenchOverlayTest {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory } ?: error("no assets")
    }

    private val adventSunday: LocalDate = LocalDate.of(2025, 11, 30)

    private fun french() {
        ContentStore.initFromDirectory(assets)
        ContentStore.applyVernacular(VernacularLanguage.FRENCH)
    }

    @After
    fun restore() {
        ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
    }

    @Test
    fun theMassOfTheDayIsInFrench() {
        french()
        val m = ContentStore.properForDate(adventSunday, MissalRite.RITE_1962)!!
        assertTrue(m.collect!!.eng, m.collect!!.eng.startsWith("Réveillez, Seigneur, votre puissance"))
        assertTrue(m.collect!!.lat, m.collect!!.lat.startsWith("Excita, quǽsumus, Dómine"))
        assertTrue(m.gospel.eng, m.gospel.eng.startsWith("Suite + du saint Évangile selon saint Luc"))
        assertTrue(m.epistle.eng, m.epistle.eng.contains("Frères"))
    }

    @Test
    fun theOfficeIsInFrench() {
        french()
        val lauds = ContentStore.hourForDate("laudes", adventSunday, MissalRite.RITE_1962)!!
        val collect = lauds.parts.last { it.type == "collect" }
        assertTrue(collect.eng, collect.eng!!.contains("Réveillez"))
        val psalm = lauds.parts.first { it.type == "psalm" && !it.verses.isNullOrEmpty() }
        assertTrue(psalm.verses!!.first().eng, psalm.verses!!.none { it.eng == it.lat })
        assertFalse("a psalm verse still English", psalm.verses!!.any { Regex("\\b(the|and|thou|thy)\\b").containsMatchIn(it.eng) })
        val matins = ContentStore.hourForDate("matutinum", adventSunday, MissalRite.RITE_1962)!!
        val prime = ContentStore.hourForDate("prima", LocalDate.of(2026, 11, 23), MissalRite.RITE_1962)!!
        val martyrology = prime.parts.first { it.variationKey?.endsWith("martyrologium") == true }
        assertTrue(martyrology.eng, martyrology.eng!!.startsWith("Le 24 novembre 2026"))
        assertTrue(martyrology.eng, martyrology.eng!!.contains("Jean de la Croix"))
        assertTrue(martyrology.eng, martyrology.eng!!.contains("Rendons grâces à Dieu"))
        val lesson = matins.parts.first { it.variationKey == "lectio1" }
        assertFalse(lesson.eng, Regex("\\b(the|and|of)\\b").containsMatchIn(lesson.eng!!))
    }

    @Test
    fun theOrdinaryOfTheMassIsInFrench() {
        french()
        val preces = ContentStore.missal.first { it.slug == "preces" }
        assertEquals("Prières au bas de l’autel", preces.english)
        assertTrue(preces.body[1].eng, preces.body[1].eng.contains("J’entrerai à l’autel de Dieu"))
        assertEquals("℣. Introíbo ad altáre Dei.", preces.body[1].lat)
    }

    @Test
    fun theRosaryAndTheStationsAreInFrench() {
        french()
        val ave = ContentStore.rosaryPrayers.first { it.slug == "ave" }
        assertTrue(ave.lines.first().eng, ave.lines.first().eng.startsWith("Je vous salue, Marie"))
        assertEquals("Mystères joyeux", ContentStore.mysterySets.first { it.slug == "joyful" }.english)
        assertEquals("Jésus est condamné à mort", ContentStore.stations.first().title)
        assertEquals("Matines", ContentStore.hours.first { it.slug == "matutinum" }.eng)
        val pater = ContentStore.prayers.first { it.slug == "pater" }
        assertTrue(pater.lines.first().eng, pater.lines.first().eng.startsWith("Notre Père, qui êtes aux cieux"))
        assertTrue(pater.lines.first().lat, pater.lines.first().lat.startsWith("Pater noster"))
    }

    @Test
    fun theInterfaceIsInFrench() {
        french()
        assertEquals("Réglages", ContentStore.uiString("settings.title", "Settings"))
        assertEquals("Dimanche", com.lampstandhq.introibo.data.liturgical.LiturgicalNames.weekday(0))
        assertEquals("dimanche 30 novembre", com.lampstandhq.introibo.data.liturgical.VernacularDates.weekdayDayMonth(adventSunday))
        assertEquals("lundi 1er décembre", com.lampstandhq.introibo.data.liturgical.VernacularDates.weekdayDayMonth(adventSunday.plusDays(1)))
        ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
        assertEquals("Sunday", com.lampstandhq.introibo.data.liturgical.LiturgicalNames.weekday(0))
    }

    @Test
    fun theOfficeOfTheDeadAndTheCanticlesAreInFrench() {
        french()
        // the Office of the Dead opens from its template
        val dead = ContentStore.hours.first { it.slug == "office-of-the-dead" }
        val english = Regex("\\b(the|and|thy|thou|hath|unto)\\b", RegexOption.IGNORE_CASE)
        val texts = dead.parts.flatMap { p -> listOfNotNull(p.eng, p.engR) + (p.verses?.map { it.eng } ?: emptyList()) }
        assertTrue("${texts.count { english.containsMatchIn(it) }} English texts", texts.count { english.containsMatchIn(it) } < 15)
        // the Benedictus at Lauds, verse for verse
        val lauds = ContentStore.hourForDate("laudes", adventSunday, MissalRite.RITE_1962)!!
        val benedictus = lauds.parts.first { it.type == "canticle" && it.verses?.firstOrNull()?.lat?.startsWith("Benedíctus") == true }
        assertFalse(benedictus.verses!!.first().eng, english.containsMatchIn(benedictus.verses!!.joinToString(" ") { it.eng }))
        // the headings the assembly gives in English
        assertEquals("Verset", OfficeLabels.display("Versicle"))
        assertEquals("Bénédiction avant la Léctio I", OfficeLabels.display("Blessing before Léctio I"))
        assertEquals("Psalmus 50", OfficeLabels.display("Psalmus 50"))
    }

    @Test
    fun theCalendarNamesTheDayInFrench() {
        french()
        val name = ContentStore.ordoNameEnglish("Dominica I Adventus")!!
        assertTrue(name, name.contains("imanche de l’Avent"))
    }

    @Test
    fun theLearningPagesAreInFrenchAndEnglishComesBack() {
        ContentStore.initFromDirectory(assets)
        ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
        val english = ContentStore.properForDate(adventSunday, MissalRite.RITE_1962)!!.collect!!.eng
        val saint = ContentStore.saints.first().title
        val article = ContentStore.reference.first().summary
        ContentStore.applyVernacular(VernacularLanguage.FRENCH)
        assertNotEquals(saint, ContentStore.saints.first().title)
        assertNotEquals(article, ContentStore.reference.first().summary)
        assertNotEquals(english, ContentStore.properForDate(adventSunday, MissalRite.RITE_1962)!!.collect!!.eng)
        ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
        assertEquals(english, ContentStore.properForDate(adventSunday, MissalRite.RITE_1962)!!.collect!!.eng)
    }

    @Test
    fun countsTakeTheSingularAtZeroAndOneInFrench() {
        french()
        assertEquals("0 prière", ContentStore.uiPlural("prayers.count", 0, "{0} prayer", "{0} prayers").replace("{0}", "0"))
        assertEquals("1 prière", ContentStore.uiPlural("prayers.count", 1, "{0} prayer", "{0} prayers").replace("{0}", "1"))
        assertEquals("2 prières", ContentStore.uiPlural("prayers.count", 2, "{0} prayer", "{0} prayers").replace("{0}", "2"))
        ContentStore.applyVernacular(VernacularLanguage.ENGLISH)
        assertEquals("0 prayers", ContentStore.uiPlural("prayers.count", 0, "{0} prayer", "{0} prayers").replace("{0}", "0"))
        assertEquals("1 prayer", ContentStore.uiPlural("prayers.count", 1, "{0} prayer", "{0} prayers").replace("{0}", "1"))
        ContentStore.applyVernacular(VernacularLanguage.SPANISH)
        assertEquals("0 oraciones", ContentStore.uiPlural("prayers.count", 0, "{0} prayer", "{0} prayers").replace("{0}", "0"))
        assertEquals("1 oración", ContentStore.uiPlural("prayers.count", 1, "{0} prayer", "{0} prayers").replace("{0}", "1"))
    }

}
