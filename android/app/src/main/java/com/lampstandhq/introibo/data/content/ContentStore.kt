package com.lampstandhq.introibo.data.content

import android.content.Context
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.model.ConfessionGuide
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.data.model.ExamenEntry
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.MissalSection
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

        val psalter: Map<String, Map<String, Hour.Part>> =
            load("psalter_weekly.json") ?: emptyMap()
        val hymns: Map<String, Map<String, Hour.Part>> =
            load("hymns_seasonal.json") ?: emptyMap()

        officeAssembler = OfficeAssembler(
            weeklyPsalter = psalter,
            seasonalHymns = hymns,
            marianAntiphons = marianAntiphons,
        )
    }

    // ---- Convenience lookups ----

    fun proper(slug: String): MassProper? =
        propers.firstOrNull { it.slug == slug }

    fun hour(slug: String): Hour? =
        hours.firstOrNull { it.slug == slug }

    fun hourForToday(slug: String): Hour? {
        val template = hour(slug) ?: return null
        return officeAssembler.assemble(template, LiturgicalContext.current())
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
