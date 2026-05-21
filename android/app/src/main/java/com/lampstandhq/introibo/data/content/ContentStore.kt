package com.lampstandhq.introibo.data.content

import android.content.Context
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.data.model.ConfessionGuide
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.data.model.ExamenEntry
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.MissalProperEntry
import com.lampstandhq.introibo.data.model.MissalSection
import com.lampstandhq.introibo.data.model.OrdoEntry
import com.lampstandhq.introibo.data.model.MysterySetData
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.data.model.RosaryPrayer
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.data.model.Station
import kotlinx.serialization.json.Json

/**
 * Loads bundled JSON content from Android assets and keeps it in memory.
 * Port of Introibo/Data/ContentStore.swift.
 *
 * Call [init] once with an application [Context] (typically in Application.onCreate)
 * before accessing any collections.
 */
object ContentStore {

    // Lazy-init JSON parser -- lenient so trailing commas / unknown keys
    // in the asset files don't crash the app.
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private lateinit var appContext: Context

    var prayers: List<Prayer> = emptyList()
        private set
    var reference: List<ReferenceEntry> = emptyList()
        private set
    var saints: List<Saint> = emptyList()
        private set
    var courses: List<Course> = emptyList()
        private set
    var missal: List<MissalSection> = emptyList()
        private set
    var mysterySets: List<MysterySetData> = emptyList()
        private set
    var rosaryPrayers: List<RosaryPrayer> = emptyList()
        private set
    var stations: List<Station> = emptyList()
        private set
    var hours: List<Hour> = emptyList()
        private set
    var marianAntiphons: List<MarianAntiphonData> = emptyList()
        private set
    var examen: List<ExamenEntry> = emptyList()
        private set
    var confessionGuides: List<ConfessionGuide> = emptyList()
        private set
    var propers: List<MassProper> = emptyList()
        private set

    private var missalTempora: Map<String, MissalProperEntry> = emptyMap()
    private var missalSanctoral: Map<String, MissalProperEntry> = emptyMap()
    private var sanctoralPropers: Map<String, Map<String, Hour.Part>> = emptyMap()
    private var ordoData: Map<String, OrdoEntry> = emptyMap()
    private var ordoData1955: Map<String, OrdoEntry> = emptyMap()
    private var ordoDataPre1955: Map<String, OrdoEntry> = emptyMap()
    private lateinit var officeAssembler: OfficeAssembler

    /**
     * Initialise the store by loading all bundled JSON from [context]'s assets.
     * Safe to call more than once (subsequent calls are no-ops).
     */
    fun init(context: Context) {
        if (::appContext.isInitialized) return
        appContext = context.applicationContext

        prayers          = load("prayers.json")            ?: emptyList()
        reference        = load("reference.json")          ?: emptyList()
        saints           = load("saints.json")             ?: emptyList()
        courses          = load("courses.json")            ?: emptyList()
        missal           = load("missal.json")             ?: emptyList()
        mysterySets      = load("mysteries.json")          ?: emptyList()
        rosaryPrayers    = load("rosary_prayers.json")     ?: emptyList()
        stations         = load("stations.json")           ?: emptyList()
        hours            = load("hours.json")              ?: emptyList()
        marianAntiphons  = load("marian_antiphons.json")   ?: emptyList()
        examen           = load("confession_examen.json")  ?: emptyList()
        confessionGuides = load("confession_guides.json")  ?: emptyList()
        propers          = load("propers.json")            ?: emptyList()
        missalTempora    = load("missal_tempora.json")    ?: emptyMap()
        missalSanctoral  = load("missal_sanctoral.json")  ?: emptyMap()
        sanctoralPropers = load("sanctoral_propers.json") ?: emptyMap()
        ordoData         = load("ordo.json")              ?: emptyMap()
        ordoData1955     = load("ordo_1955.json")         ?: emptyMap()
        ordoDataPre1955  = load("ordo_pre1955.json")      ?: emptyMap()

        val psalter: Map<String, Map<String, Hour.Part>> =
            load("psalter_weekly.json") ?: emptyMap()
        val hymns: Map<String, Map<String, Hour.Part>> =
            load("hymns_seasonal.json") ?: emptyMap()
        val temporal: Map<String, Map<String, Hour.Part>> =
            load("temporal_propers.json") ?: emptyMap()

        officeAssembler = OfficeAssembler(
            weeklyPsalter = psalter,
            seasonalHymns = hymns,
            temporalPropers = temporal,
            marianAntiphons = marianAntiphons,
        )
    }

    // ---- Convenience lookups ----

    fun proper(slug: String): MassProper? =
        propers.firstOrNull { it.slug == slug }

    val allPropers: List<MassProper> by lazy {
        val combined = mutableMapOf<String, MassProper>()
        for ((key, entry) in missalTempora) {
            entry.toMassProper(key)?.let { combined[key] = it }
        }
        for ((key, entry) in missalSanctoral) {
            entry.toMassProper(key)?.let { combined[key] = it }
        }
        val doKeys = combined.keys.toSet()
        for (p in propers) {
            if (p.slug in doKeys) continue
            if (hasDOEquivalent(p.slug, doKeys)) continue
            combined[p.slug] = p
        }
        combined.values.sortedBy { it.slug }
    }

    private fun hasDOEquivalent(slug: String, doKeys: Set<String>): Boolean {
        if (slug.startsWith("sancti-")) return slug.removePrefix("sancti-") in doKeys
        val mappings = listOf(
            "easter-" to "pasc", "advent-" to "adv", "lent-" to "quad",
            "christmas-" to "nat", "pentecost-" to "pent", "epiphany-" to "epi",
            "quinquagesima-" to "quadp3-",
        )
        for ((prefix, doPrefix) in mappings) {
            if (slug.startsWith(prefix)) {
                return "$doPrefix${slug.removePrefix(prefix)}" in doKeys
            }
        }
        return false
    }

    fun ordoForDate(date: java.time.LocalDate, rite: MissalRite = MissalRite.RITE_1962): OrdoEntry? {
        val key = "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
        return when (rite) {
            MissalRite.RITE_1955 -> ordoData1955[key]
            MissalRite.PRE_1955 -> ordoDataPre1955[key]
            else -> ordoData[key]
        }
    }

    fun properForDate(date: java.time.LocalDate, rite: MissalRite = MissalRite.RITE_1962): MassProper? {
        val entry = ordoForDate(date, rite) ?: return null
        val key = entry.winnerKey
        if (entry.winner == "sanctoral") {
            missalSanctoral[key]?.toMassProper(key)?.let { return it }
            // Christmas: ordo key "12-25" but Mass data is keyed by 12-25m1/m2/m3.
            // Default to the Day Mass (m3).
            if (key == "12-25") {
                missalSanctoral["12-25m3"]?.toMassProper("12-25m3")?.let { return it }
            }
        }
        missalTempora[key]?.toMassProper(key)?.let { return it }
        missalSanctoral[key]?.toMassProper(key)?.let { return it }
        // Inheritance: octave days inherit Mass propers from their feast day
        inheritedTemporalKey(key)?.let { parent ->
            missalTempora[parent]?.toMassProper(parent)?.let { return it }
        }
        return propers.firstOrNull { it.slug == key }
    }

    private fun inheritedTemporalKey(key: String): String? {
        // Ascension octave (Pasc5-5 through Pasc6-4) inherits from Pasc5-4
        val ascensionOctave = setOf(
            "pasc5-5", "pasc5-6", "pasc6-0", "pasc6-1",
            "pasc6-2", "pasc6-3", "pasc6-4"
        )
        if (key in ascensionOctave) return "pasc5-4"
        return null
    }

    fun hour(slug: String): Hour? =
        hours.firstOrNull { it.slug == slug }

    fun hourForToday(slug: String, rite: MissalRite = MissalRite.RITE_1962): Hour? {
        val template = hour(slug) ?: return null
        val ctx = LiturgicalContext.current()
        var assembled = officeAssembler.assemble(template, ctx)

        val ordo = ordoForDate(ctx.date, rite)
        if (ordo != null) {
            if (ordo.winner == "sanctoral") {
                val saint = sanctoralPropers[ordo.winnerKey]
                if (saint != null) {
                    assembled = applyProperOverrides(assembled, saint)
                }
            } else {
                val temporalKey = ordo.temporal
                if (temporalKey != null) {
                    val tempOverrides = officeAssembler.temporalPropers[temporalKey]
                    if (tempOverrides != null) {
                        assembled = applyProperOverrides(assembled, tempOverrides)
                    }
                }
            }
        }
        return assembled
    }

    private fun applyProperOverrides(hour: Hour, overrides: Map<String, Hour.Part>): Hour {
        val updatedParts = hour.parts.map { part ->
            val key = part.variationKey
            if (key != null && overrides.containsKey(key)) return@map overrides[key]!!
            if (part.type == "collect" && overrides.containsKey("collect")) return@map overrides["collect"]!!
            part
        }
        return hour.copy(parts = updatedParts)
    }

    fun mysterySet(slug: String): MysterySetData? =
        mysterySets.firstOrNull { it.slug == slug }

    fun prayer(slug: String): Prayer? =
        prayers.firstOrNull { it.slug == slug }

    fun prayers(category: String): List<Prayer> =
        prayers.filter { it.category == category }

    /**
     * Returns prayers grouped by category, preserving the order in which
     * categories first appear in the source file (liturgically meaningful).
     */
    fun prayersByCategory(): List<Pair<String, List<Prayer>>> {
        val seen = mutableListOf<String>()
        val buckets = mutableMapOf<String, MutableList<Prayer>>()
        for (p in prayers) {
            if (p.category !in buckets) {
                seen.add(p.category)
                buckets[p.category] = mutableListOf()
            }
            buckets[p.category]!!.add(p)
        }
        return seen.map { it to (buckets[it] ?: emptyList()) }
    }

    // ---- Generic asset loader ----

    private inline fun <reified T> load(filename: String): T? {
        return try {
            val text = appContext.assets.open(filename).bufferedReader().use { it.readText() }
            json.decodeFromString<T>(text)
        } catch (e: Exception) {
            // Log but don't crash -- mirrors the iOS assertionFailure behaviour
            // which only fires in debug builds.
            android.util.Log.e("ContentStore", "Failed to load $filename: ${e.message}")
            null
        }
    }
}

// Model types now live in data.model.* — no more placeholders needed.
