package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.VernacularLanguage
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Spanish-mode audit dump: every assembled hour and every day's Mass
 * proper with the Spanish overlay applied, so the vernacular a Spanish
 * reader actually sees can be scanned for texts still in English.
 * Runs only when SPANISH_AUDIT_DIR is set.
 */
class SpanishAuditDump {
    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.firstOrNull { it.isDirectory } ?: error("no assets")
    }
    private val json = Json { prettyPrint = false }

    @Test
    fun dump() {
        val dir = System.getenv("SPANISH_AUDIT_DIR") ?: return
        val start = LocalDate.parse(System.getenv("SPANISH_AUDIT_START") ?: "2025-11-30")
        val end = LocalDate.parse(System.getenv("SPANISH_AUDIT_END") ?: "2026-11-28")
        val rites = (System.getenv("SPANISH_AUDIT_RITES") ?: "1962").split(",").map { r -> MissalRite.entries.first { it.rawValue == r } }
        val hours = listOf("matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium")
        ContentStore.initFromDirectory(assets)
        ContentStore.applyVernacular(VernacularLanguage.SPANISH)
        var d = start
        while (!d.isAfter(end)) {
            for (rite in rites) {
                val out = File(dir, "${rite.rawValue}/$d.json"); out.parentFile.mkdirs()
                val hoursJson = hours.associateWith { slug ->
                    ContentStore.hourForDate(slug, d, rite)?.parts?.map { p ->
                        mapOf("type" to p.type, "label" to p.label, "vk" to p.variationKey, "title" to p.title,
                            "lat" to p.lat, "eng" to p.eng, "latR" to p.latR, "engR" to p.engR,
                            "ant" to p.antiphonLat, "antEng" to p.antiphonEng,
                            "verses" to p.verses?.map { v -> mapOf("lat" to v.lat, "eng" to v.eng) }).filterValues { it != null }
                    }
                }
                val proper = ContentStore.properForDate(d, rite)?.let { m ->
                    fun t(x: com.lampstandhq.introibo.data.model.ProperText?) = x?.let { mapOf("lat" to it.lat, "eng" to it.eng) }
                    mapOf("title" to m.title, "english" to m.english,
                        "introit" to t(m.introit), "collect" to t(m.collect), "gradual" to t(m.gradual), "alleluia" to t(m.alleluia),
                        "tract" to t(m.tract), "sequence" to t(m.sequence), "offertory" to t(m.offertory), "secret" to t(m.secret),
                        "communion" to t(m.communion), "postcommunion" to t(m.postcommunion),
                        "epistle" to mapOf("ref" to m.epistle.ref, "lat" to m.epistle.lat, "eng" to m.epistle.eng),
                        "gospel" to mapOf("ref" to m.gospel.ref, "lat" to m.gospel.lat, "eng" to m.gospel.eng)).filterValues { it != null }
                }
                val ordo = ContentStore.ordoForDate(d, rite)
                out.writeText(json.encodeToString(JsonElement.serializer(), toJson(mapOf("date" to d.toString(), "rite" to rite.rawValue,
                    "ordoName" to ordo?.name, "ordoNameEs" to ordo?.name?.let { ContentStore.ordoNameEnglish(it) },
                    "hours" to hoursJson, "proper" to proper))))
            }
            d = d.plusDays(1)
        }
    }

    private fun toJson(v: Any?): JsonElement = when (v) {
        null -> JsonNull
        is String -> JsonPrimitive(v)
        is Number -> JsonPrimitive(v)
        is Boolean -> JsonPrimitive(v)
        is Map<*, *> -> JsonObject(v.entries.associate { (k, x) -> k.toString() to toJson(x) })
        is List<*> -> JsonArray(v.map { toJson(it) })
        else -> JsonPrimitive(v.toString())
    }
}
