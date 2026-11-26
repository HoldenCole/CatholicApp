package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.ConfessionGuide
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.data.model.ExamenEntry
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import com.lampstandhq.introibo.data.model.MartyrologyData
import com.lampstandhq.introibo.data.model.MissalSection
import com.lampstandhq.introibo.data.model.MysterySetData
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.data.model.RosaryPrayer
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.data.model.Station
import com.lampstandhq.introibo.storage.settings.VernacularLanguage
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Test
import java.io.File

/**
 * Vernacular QA dump of everything outside the Office and the Mass of the
 * day: the prayer library, the Rosary, the Stations, confession, the
 * Ordinary and the Canon's variants, the Marian antiphons, the
 * Martyrology, the hours' names, the saints, reference and course pages,
 * the daily psalm and the calendar's feast names, as the store holds them
 * once CONTENT_AUDIT_LANG (en, es, fr) is applied. Dumping the same
 * content in each language and comparing shows what a language still
 * leaves in English. Runs only when CONTENT_AUDIT_DIR is set.
 */
class ContentAuditDump {
    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }.firstOrNull { it.isDirectory } ?: error("no assets")
    }
    private val json = Json { prettyPrint = true; encodeDefaults = true }

    @Suppress("UNCHECKED_CAST")
    private fun <T> field(name: String): T =
        ContentStore::class.java.getDeclaredField(name).apply { isAccessible = true }.get(ContentStore) as T

    @Test
    fun dump() {
        val dir = System.getenv("CONTENT_AUDIT_DIR") ?: return
        val lang = VernacularLanguage.entries.first { it.rawValue == (System.getenv("CONTENT_AUDIT_LANG") ?: "en") }
        ContentStore.initFromDirectory(assets)
        ContentStore.applyVernacular(lang)
        val s = ContentStore
        val tree = mapOf(
            "prayers" to json.encodeToJsonElement(ListSerializer(Prayer.serializer()), s.prayers),
            "rosary_prayers" to json.encodeToJsonElement(ListSerializer(RosaryPrayer.serializer()), s.rosaryPrayers),
            "mysteries" to json.encodeToJsonElement(ListSerializer(MysterySetData.serializer()), s.mysterySets),
            "stations" to json.encodeToJsonElement(ListSerializer(Station.serializer()), s.stations),
            "confession_examen" to json.encodeToJsonElement(ListSerializer(ExamenEntry.serializer()), s.examen),
            "confession_guides" to json.encodeToJsonElement(ListSerializer(ConfessionGuide.serializer()), s.confessionGuides),
            "missal" to json.encodeToJsonElement(ListSerializer(MissalSection.serializer()), s.missal),
            "canon_variants" to json.encodeToJsonElement(
                MapSerializer(String.serializer(), MapSerializer(String.serializer(), MapSerializer(String.serializer(), String.serializer()))),
                field("canonVariants")),
            "marian_antiphons" to json.encodeToJsonElement(ListSerializer(MarianAntiphonData.serializer()), s.marianAntiphons),
            "martyrology" to json.encodeToJsonElement(MartyrologyData.serializer(), s.martyrology!!),
            "hours" to json.encodeToJsonElement(ListSerializer(Hour.serializer()), s.hours),
            "saints" to json.encodeToJsonElement(ListSerializer(Saint.serializer()), s.saints),
            "reference" to json.encodeToJsonElement(ListSerializer(ReferenceEntry.serializer()), s.reference),
            "courses" to json.encodeToJsonElement(ListSerializer(Course.serializer()), s.courses),
            "daily_psalm" to json.encodeToJsonElement(MapSerializer(String.serializer(), String.serializer()), s.dailyPsalmES),
            "ordo_names" to json.encodeToJsonElement(MapSerializer(String.serializer(), String.serializer()), field("ordoNamesEn")),
        )
        File(dir).mkdirs()
        File(dir, "content_${lang.rawValue}.json").writeText(json.encodeToString(JsonObject.serializer(), JsonObject(tree)))
    }
}
