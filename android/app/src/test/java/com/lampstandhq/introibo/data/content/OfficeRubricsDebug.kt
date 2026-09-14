package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** Prints the assembled hour for OFFICE_DEBUG="2026-04-13:nona,2026-06-11:vesperae" (rite OFFICE_DEBUG_RITE). */
class OfficeRubricsDebug {
    @Test
    fun debug() {
        val spec = System.getenv("OFFICE_DEBUG") ?: return
        val rite = MissalRite.entries.first { it.rawValue == (System.getenv("OFFICE_DEBUG_RITE") ?: "1962") }
        val assets = listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets").map { File(it) }.first { it.isDirectory }
        ContentStore.initFromDirectory(assets)
        for (item in spec.split(",")) {
            val (d, h) = item.split(":")
            val date = LocalDate.parse(d)
            println("===== $d $h ${ContentStore.ordoForDate(date, rite)?.name}")
            val hour = ContentStore.hourForDate(h, date, rite) ?: continue
            for (p in hour.parts) {
                val text = (p.lat ?: p.v1Lat ?: p.antiphonLat ?: "").replace("\n", " / ").take(70)
                println("  ${p.type.padEnd(10)} ${(p.variationKey ?: "-").padEnd(26)} ${(p.label ?: "").take(22).padEnd(22)} | $text | ant=${(p.antiphonLat ?: "").take(40)} | ref=${p.ref ?: ""}")
            }
        }
    }
}
