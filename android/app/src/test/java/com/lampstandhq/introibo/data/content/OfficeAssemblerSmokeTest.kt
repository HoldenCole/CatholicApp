package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import kotlinx.serialization.json.Json
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Assembles every canonical hour for every day across three liturgical years
 * with the real bundled data — the code path behind ContentStore.hourForToday
 * that shipped untested in the 1.2.1 parity update.
 *
 * This is a pure-JVM smoke test: OfficeAssembler and LiturgicalContext need no
 * Android Context. It catches date- and data-dependent throws (the class of
 * bug that turns into a crash only when a user opens the Office on the wrong
 * day) and gross data loss (an hour assembling to zero parts).
 */
class OfficeAssemblerSmokeTest {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory }
            ?: error("cannot locate assets dir")
    }

    private inline fun <reified T> load(name: String): T =
        json.decodeFromString(File(assets, name).readText())

    @Test
    fun everyHourAssemblesForEveryDay() {
        val hours: List<Hour> = load("hours.json")
        assertTrue("hours.json must not be empty", hours.isNotEmpty())

        val assembler = OfficeAssembler(
            weeklyPsalter = load("psalter_weekly.json"),
            seasonalHymns = load("hymns_seasonal.json"),
            temporalPropers = load("temporal_propers.json"),
            marianAntiphons = load<List<MarianAntiphonData>>("marian_antiphons.json"),
            psalter = load("psalter.json"),
        )

        var assembledCount = 0
        var date = LocalDate.of(2025, 1, 1)
        val end = LocalDate.of(2027, 12, 31)
        while (!date.isAfter(end)) {
            val ctx = LiturgicalContext.forDate(date)
            for (hour in hours) {
                for (festal in listOf(false, true)) {
                    val out = try {
                        assembler.assemble(
                            template = hour,
                            context = ctx,
                            isFestal = festal,
                            festalCompline = festal,
                            festalLittleHours = festal,
                            matinsNocturns = if (festal) 3 else 1,
                            matinsTeDeum = festal,
                        )
                    } catch (t: Throwable) {
                        throw AssertionError(
                            "assemble threw for ${hour.slug} on $date (festal=$festal): $t", t,
                        )
                    }
                    assertTrue(
                        "${hour.slug} on $date assembled to zero parts",
                        out.parts.isNotEmpty(),
                    )
                    assembledCount++
                }
            }
            date = date.plusDays(1)
        }
        // 3 years x ~365 days x 8 hours x 2 variants
        assertTrue("suspiciously few assemblies ran: $assembledCount", assembledCount > 17000)
    }
}
