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

        ContentStore.initFromDirectory(assets)
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
                        ).filterValues { it != null }
                    }
                }
                val doc = mapOf(
                    "date" to d.toString(), "rite" to rite.rawValue,
                    "ordo" to ordo?.let { mapOf("name" to it.name, "winner" to it.winner, "winnerKey" to it.winnerKey,
                        "rank" to it.rank, "season" to it.season, "commemoration" to it.commemoration) },
                    "hours" to hoursJson,
                )
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
