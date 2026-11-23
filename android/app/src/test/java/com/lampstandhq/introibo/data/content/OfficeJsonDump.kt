package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Differential-QA dump: every assembled hour for every day of a range, in
 * every rite, as JSON — the app side of the comparison against Divinum
 * Officium (scripts/office_qa). Runs only when OFFICE_JSON_DIR is set so
 * the ordinary suite is not slowed down.
 *
 *   OFFICE_JSON_DIR=/tmp/appqa OFFICE_JSON_START=2025-11-30 \
 *   OFFICE_JSON_END=2026-11-28 gradle :app:testDebugUnitTest --tests '*OfficeJsonDump*'
 *
 * OFFICE_JSON_LANG=es dumps the Spanish office. OFFICE_JSON_FULL=1 adds every other field of a part (the vernacular
 * side, the intoned-antiphon flag) and the day's Mass proper: the Android
 * half of the iOS/Android parity diff (scripts/office_qa/ios_parity).
 */
class OfficeJsonDump {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory } ?: error("no assets")
    }

    private val json = Json { prettyPrint = false; encodeDefaults = false }

    @Test
    fun dump() {
        val dir = System.getenv("OFFICE_JSON_DIR") ?: return
        val start = LocalDate.parse(System.getenv("OFFICE_JSON_START") ?: "2025-11-30")
        val end = LocalDate.parse(System.getenv("OFFICE_JSON_END") ?: "2026-11-28")
        val rites = (System.getenv("OFFICE_JSON_RITES") ?: "1962,1955,pre1955").split(",")
            .map { r -> MissalRite.entries.first { it.rawValue == r } }
        val hours = listOf("matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium")
        val full = System.getenv("OFFICE_JSON_FULL") == "1"

        ContentStore.initFromDirectory(assets)
        if (System.getenv("OFFICE_JSON_LANG") == "es") {
            ContentStore.applyVernacular(com.lampstandhq.introibo.storage.settings.VernacularLanguage.SPANISH)
        }
        var d = start
        while (!d.isAfter(end)) {
            for (rite in rites) {
                val ordo = ContentStore.ordoForDate(d, rite)
                val out = File(dir, "${rite.rawValue}/$d.json")
                out.parentFile.mkdirs()
                val hoursJson = hours.associateWith { slug ->
                    val h = ContentStore.hourForDate(slug, d, rite)
                    h?.parts?.map { p ->
                        mapOf(
                            "type" to p.type, "label" to p.label, "vk" to p.variationKey,
                            "ref" to p.ref, "lat" to p.lat, "latR" to p.latR,
                            "v1" to p.v1Lat, "r1" to p.r1Lat, "v2" to p.v2Lat, "r2" to p.r2Lat,
                            "ant" to p.antiphonLat,
                            "verses" to p.verses?.map { it.lat },
                        ).let { base ->
                            if (!full) base else base + mapOf(
                                "title" to p.title, "eng" to p.eng, "engR" to p.engR,
                                "v1e" to p.v1Eng, "r1e" to p.r1Eng, "v2e" to p.v2Eng, "r2e" to p.r2Eng,
                                "ante" to p.antiphonEng, "engBody" to p.engBody,
                                "versesE" to p.verses?.map { it.eng },
                                "intoned" to p.antiphonIntoned, "season" to p.season,
                            )
                        }.filterValues { it != null }
                    }
                }
                val mass = if (!full) null else ContentStore.properForDate(d, rite)?.let { m ->
                    fun t(x: com.lampstandhq.introibo.data.model.ProperText?) = x?.let { mapOf("lat" to it.lat, "eng" to it.eng) }
                    mapOf(
                        "slug" to m.slug, "title" to m.title, "rank" to m.rank, "color" to m.color,
                        "introit" to t(m.introit), "collect" to t(m.collect),
                        "epistle" to mapOf("ref" to m.epistle.ref, "lat" to m.epistle.lat, "eng" to m.epistle.eng),
                        "gradual" to t(m.gradual), "alleluia" to t(m.alleluia), "tract" to t(m.tract), "sequence" to t(m.sequence),
                        "gospel" to mapOf("ref" to m.gospel.ref, "lat" to m.gospel.lat, "eng" to m.gospel.eng),
                        "offertory" to t(m.offertory), "secret" to t(m.secret),
                        "communion" to t(m.communion), "postcommunion" to t(m.postcommunion),
                        "preface" to m.preface, "glor" to m.glorOverride, "credo" to m.credoOverride,
                    ).filterValues { it != null }
                }
                val doc = mapOf(
                    "date" to d.toString(), "rite" to rite.rawValue,
                    "ordo" to ordo?.let { mapOf("name" to it.name, "winner" to it.winner, "winnerKey" to it.winnerKey,
                        "rank" to it.rank, "season" to it.season, "commemoration" to it.commemoration) },
                    "hours" to hoursJson,
                ).let { if (mass != null) it + ("mass" to mass) else it }
                out.writeText(json.encodeToString(kotlinx.serialization.json.JsonElement.serializer(), toJson(doc)))
            }
            d = d.plusDays(1)
        }
    }

    private fun toJson(v: Any?): kotlinx.serialization.json.JsonElement = when (v) {
        null -> kotlinx.serialization.json.JsonNull
        is String -> kotlinx.serialization.json.JsonPrimitive(v)
        is Number -> kotlinx.serialization.json.JsonPrimitive(v)
        is Boolean -> kotlinx.serialization.json.JsonPrimitive(v)
        is Map<*, *> -> kotlinx.serialization.json.JsonObject(v.entries.associate { (k, x) -> k.toString() to toJson(x) })
        is List<*> -> kotlinx.serialization.json.JsonArray(v.map { toJson(it) })
        else -> kotlinx.serialization.json.JsonPrimitive(v.toString())
    }
}
