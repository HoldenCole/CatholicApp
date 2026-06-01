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

    // Canon variant data: { "communicantes": { "easter": { "lat": ..., "eng": ... }, ... }, "hanc_igitur": { ... } }
    private var canonVariants: Map<String, Map<String, Map<String, String>>> = emptyMap()

    private var missalTempora: Map<String, MissalProperEntry> = emptyMap()
    private var missalSanctoral: Map<String, MissalProperEntry> = emptyMap()
    private var sanctoralPropers: Map<String, Map<String, Hour.Part>> = emptyMap()
    // Commune (common Office) parts + saint→commune map (see iOS ContentStore).
    private var communeOffice: Map<String, Map<String, Hour.Part>> = emptyMap()
    private var saintCommune: Map<String, String> = emptyMap()
    // Feast->feast Office inheritance via `ex Sancti/MM-DD` (see iOS ContentStore).
    private var saintOfficeInherit: Map<String, String> = emptyMap()
    private var ordoData: Map<String, OrdoEntry> = emptyMap()
    private var ordoData1955: Map<String, OrdoEntry> = emptyMap()
    private var ordoDataPre1955: Map<String, OrdoEntry> = emptyMap()
    // Latin ordo `name` -> English translation (translate_ordo_names.py).
    private var ordoNamesEn: Map<String, String> = emptyMap()
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
        communeOffice    = load("commune_office.json")    ?: emptyMap()
        saintCommune     = load("saint_commune.json")     ?: emptyMap()
        saintOfficeInherit = load("saint_office_inherit.json") ?: emptyMap()
        ordoData         = load("ordo.json")              ?: emptyMap()
        ordoData1955     = load("ordo_1955.json")         ?: emptyMap()
        ordoDataPre1955  = load("ordo_pre1955.json")      ?: emptyMap()
        ordoNamesEn      = load("ordo_names_en.json")     ?: emptyMap()
        canonVariants    = load("canon_variants.json")    ?: emptyMap()

        val psalterWeekly: Map<String, Map<String, Hour.Part>> =
            load("psalter_weekly.json") ?: emptyMap()
        val hymns: Map<String, Map<String, Hour.Part>> =
            load("hymns_seasonal.json") ?: emptyMap()
        val temporal: Map<String, Map<String, Hour.Part>> =
            load("temporal_propers.json") ?: emptyMap()
        val psalterText: Map<String, Map<String, List<String>>> =
            load("psalter.json") ?: emptyMap()

        officeAssembler = OfficeAssembler(
            weeklyPsalter = psalterWeekly,
            seasonalHymns = hymns,
            temporalPropers = temporal,
            marianAntiphons = marianAntiphons,
            psalter = psalterText,
        )
    }

    // ---- Search index (Phase 1: index core) ----
    //
    // Built lazily on first access. Owned here so the whole app shares one
    // folded corpus. Mirror: iOS ContentStore.searchIndex.
    // `by lazy` is thread-safe (LazyThreadSafetyMode.SYNCHRONIZED) by default;
    // call prepareSearchIndex() on a background thread at launch to avoid
    // blocking the first reader.

    val searchIndex: com.lampstandhq.introibo.data.search.SearchIndex by lazy {
        com.lampstandhq.introibo.data.search.SearchIndex.build(this)
    }

    /** Eagerly builds the search index off the main thread. Idempotent. */
    fun prepareSearchIndex() {
        Thread { searchIndex }.start()
    }

    // ---- Link graph (Phase 3: contextual-links reverse index) ----
    //
    // The bidirectional "Referenced By" reverse index. Built lazily on first
    // access, exactly like searchIndex. Owned here so the whole app shares one
    // graph. Mirror: iOS ContentStore.linkGraph.
    // `by lazy` is thread-safe (LazyThreadSafetyMode.SYNCHRONIZED) by default;
    // call prepareLinkGraph() on a background thread at launch to avoid blocking
    // the first reader.

    val linkGraph: com.lampstandhq.introibo.data.links.LinkGraph by lazy {
        com.lampstandhq.introibo.data.links.LinkGraph.build(this)
    }

    /** Eagerly builds the link graph off the main thread. Idempotent. */
    fun prepareLinkGraph() {
        Thread { linkGraph }.start()
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

    /** English translation of a Latin ordo `name`, or null if none is bundled. */
    fun ordoNameEnglish(latin: String): String? = ordoNamesEn[latin]

    fun ordoForDate(date: java.time.LocalDate, rite: MissalRite = MissalRite.RITE_1962): OrdoEntry? {
        val key = "%04d-%02d-%02d".format(date.year, date.monthValue, date.dayOfMonth)
        return when (rite) {
            MissalRite.RITE_1955 -> ordoData1955[key]
            MissalRite.PRE_1955 -> ordoDataPre1955[key]
            else -> ordoData[key]
        }
    }

    /**
     * Inclusive [min, max] year span actually covered by the bundled ordo for
     * [rite]. The liturgical calendar uses this to bound month navigation so a
     * user can never page into a year with no ordo data. Computed from the table
     * keys ("yyyy-MM-dd") so it self-corrects if the data range changes.
     * Mirrors iOS `ContentStore.ordoYearRange(rite:)`.
     */
    fun ordoYearRange(rite: MissalRite = MissalRite.RITE_1962): IntRange {
        val data = when (rite) {
            MissalRite.RITE_1955 -> ordoData1955
            MissalRite.PRE_1955 -> ordoDataPre1955
            else -> ordoData
        }
        val years = data.keys.mapNotNull { it.take(4).toIntOrNull() }
        val lo = years.minOrNull() ?: return 2024..2030
        val hi = years.maxOrNull() ?: return 2024..2030
        return lo..hi
    }

    fun properForDate(date: java.time.LocalDate, rite: MissalRite = MissalRite.RITE_1962): MassProper? {
        val entry = ordoForDate(date, rite) ?: return null
        val key = entry.winnerKey
        if (entry.winner == "sanctoral") {
            missalSanctoral[key]?.toMassProper(key, entry)?.let { return it }
            if (key == "12-25") {
                missalSanctoral["12-25m3"]?.toMassProper("12-25m3", entry)?.let { return it }
            }
            if (key == "11-02") {
                missalSanctoral["11-02m1"]?.toMassProper("11-02m1", entry)?.let { return it }
            }
        }
        // Pre-1955 rite: prefer the "r" suffixed variant if present (mirrors DO's
        // Pasc7-6r.txt / Quad6-4r.txt convention for pre-1955-specific formularies).
        if (rite == MissalRite.PRE_1955) {
            val rKey = "${key}r"
            missalTempora[rKey]?.toMassProper(rKey, entry)?.let { return it }
            missalSanctoral[rKey]?.toMassProper(rKey, entry)?.let { return it }
        }
        missalTempora[key]?.toMassProper(key, entry)?.let { return it }
        missalSanctoral[key]?.toMassProper(key, entry)?.let { return it }
        resolveCommuneRedirect(key, entry)?.let { return it }
        inheritedTemporalKey(key)?.let { parent ->
            missalTempora[parent]?.toMassProper(parent, entry)?.let { return it }
        }
        propers.firstOrNull { it.slug == key }?.let { return it }

        // Last resort: ferial days use the preceding Sunday's formulary.
        // Extract the temporal key (e.g. "pent03-4") and replace the day suffix
        // with "-0" to get the Sunday of that week (e.g. "pent03-0").
        precedingSundayKey(entry)?.let { sundayKey ->
            missalTempora[sundayKey]?.toMassProper(sundayKey, entry)?.let { return it }
            // The Sunday itself may be a stub with a commune redirect (e.g.
            // pent27-0 → epi5-0 for "resumed" Sundays after Epiphany).
            // Use a synthetic ordo entry with a non-ferial name to avoid
            // the ferial-suppression heuristic blocking the redirect.
            val sundayOrdo = OrdoEntry(
                temporal = sundayKey,
                sanctoral = entry.sanctoral,
                winner = "temporal",
                winnerKey = sundayKey,
                rank = entry.rank,
                name = missalTempora[sundayKey]?.officium ?: entry.name,
                color = entry.color,
                season = entry.season,
                commemoration = entry.commemoration,
            )
            resolveCommuneRedirect(sundayKey, sundayOrdo)?.let { return it }
        }

        return null
    }

    /**
     * Derives the preceding Sunday's temporal key from an ordo entry.
     * Given a temporal key like "pent03-4", "adv1-3", "quad2-6", "epi1-2",
     * replaces the trailing "-D" day suffix with "-0" (the Sunday).
     * Returns null if the entry has no temporal key, is already a Sunday, or
     * does not match the expected format.
     */
    private fun precedingSundayKey(entry: OrdoEntry): String? {
        val temporal = entry.temporal ?: return null
        val dashIdx = temporal.lastIndexOf('-')
        if (dashIdx < 0) return null
        val daySuffix = temporal.substring(dashIdx + 1)
        // Must be a single non-zero digit (weekday); "0" is already Sunday
        if (daySuffix.length != 1) return null
        val dayNum = daySuffix.toIntOrNull() ?: return null
        if (dayNum < 1 || dayNum > 6) return null
        return temporal.substring(0, dashIdx + 1) + "0"
    }

    /**
     * Resolves a `rule.commune` redirect on a stub entry. Mirrors the iOS
     * implementation (Introibo/Data/ContentStore.swift). See that file for
     * the full doc-comment, including the suppression rule that blocks
     * abolished-octave bleed-through (e.g., 1962 ferias inside the former
     * Sacred Heart octave must NOT inherit Sacred Heart Mass propers).
     */
    private fun resolveCommuneRedirect(key: String, ordo: OrdoEntry, depth: Int = 0): MassProper? {
        if (depth >= 4) return null
        val stub = missalTempora[key] ?: missalSanctoral[key]
        val target = stub?.rule?.commune
        if (target.isNullOrEmpty()) return null

        val parts = target.split('/', limit = 2)
        val section = if (parts.size == 2) parts[0] else ""
        val bareKey = if (parts.size == 2) parts[1] else target

        if (section.isEmpty() && bareKey.startsWith("C") && bareKey.getOrNull(1)?.isDigit() == true) {
            return null
        }

        val lowerKey = bareKey.lowercase()

        // Helper: take a resolved target's Mass propers but suppress the inheritance
        // if the ordo says the day is a ferial whose liturgical name has no lexical
        // overlap with the target's officium (i.e., the redirect points at a feast
        // that this rite does not observe on this date).
        fun gated(targetKey: String, entry: MissalProperEntry?): MassProper? {
            if (entry == null) return null
            if (redirectShouldBeSuppressed(ordo.name, entry.officium)) return null
            return entry.toMassProper(targetKey, ordo)
        }

        when (section) {
            "Sancti" -> {
                gated(bareKey, missalSanctoral[bareKey])?.let { return it }
                resolveCommuneRedirect(bareKey, ordo, depth + 1)?.let { return it }
            }
            "Tempora" -> {
                gated(lowerKey, missalTempora[lowerKey])?.let { return it }
                resolveCommuneRedirect(lowerKey, ordo, depth + 1)?.let { return it }
            }
            else -> {
                gated(lowerKey, missalTempora[lowerKey])?.let { return it }
                gated(bareKey, missalSanctoral[bareKey])?.let { return it }
                resolveCommuneRedirect(lowerKey, ordo, depth + 1)?.let { return it }
                resolveCommuneRedirect(bareKey, ordo, depth + 1)?.let { return it }
            }
        }
        return null
    }

    // ---- Commune-redirect suppression heuristic ----

    /**
     * Returns true iff the ordo's day-name has a ferial shape AND it shares no
     * significant lexical signal with the redirect target's officium. In that
     * case the redirect is deemed inapplicable for this rite-date and should be
     * suppressed (caller will fall through to the next resolution step,
     * eventually returning null if no other Mass is available).
     */
    private fun redirectShouldBeSuppressed(ordoName: String, targetOfficium: String?): Boolean {
        if (targetOfficium.isNullOrEmpty()) return false
        val lowerName = ordoName.lowercase()
        val isFerial = lowerName.startsWith("feria ") || lowerName.startsWith("sabbato ")
        if (!isFerial) return false
        val nameTokens = significantTokens(ordoName)
        val targetTokens = significantTokens(targetOfficium)
        if (nameTokens.isEmpty() || targetTokens.isEmpty()) return false
        // Latin inflection tolerance: treat tokens as matching when their
        // longest common prefix is >= 5 chars (e.g. "septuagesima" ~ "septuagesimæ",
        // "epiphaniam" ~ "epiphaniæ").
        for (n in nameTokens) {
            for (t in targetTokens) {
                if (commonPrefixLength(n, t) >= 5) return false
            }
        }
        return true
    }

    private fun commonPrefixLength(a: String, b: String): Int {
        val limit = minOf(a.length, b.length)
        var i = 0
        while (i < limit && a[i] == b[i]) i++
        return i
    }

    private fun significantTokens(s: String): List<String> {
        val lower = s.lowercase()
        val out = mutableListOf<String>()
        val current = StringBuilder()
        for (ch in lower) {
            if (ch.isLetter()) {
                current.append(ch)
            } else {
                if (current.isNotEmpty()) { out.add(current.toString()); current.setLength(0) }
            }
        }
        if (current.isNotEmpty()) out.add(current.toString())
        val romanRegex = Regex("^[ivxlcdm]+$")
        return out.filter { tok ->
            when {
                tok.length < 4 -> false
                tok in redirectSignalStopWords -> false
                romanRegex.matches(tok) -> false
                else -> true
            }
        }
    }

    /**
     * Words that are too generic to count as a liturgical "signal" when
     * comparing the ordo's day-name to a redirect target's officium. These
     * are calendar / structural words ("Feria", "Hebdomadam", …) that would
     * match across unrelated formularies and produce false positives.
     */
    private val redirectSignalStopWords: Set<String> = setOf(
        "feria", "sabbato", "dominica", "die", "dies", "infra", "post",
        "hebdomadam", "hebdomadæ", "hebdomadae", "octava", "octavam",
        "octavæ", "octavae", "festo", "festum", "commemoratio", "in",
        "ad", "ac", "et", "de", "sub", "sancti", "sanctae", "sanctæ"
    )

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
        val ordo = ordoForDate(ctx.date, rite)
        // Feasts (Semiduplex and above, rank >= 2.0) use festal psalm scheme
        // at Lauds & Vespers; ferias and Simples use ferial psalms.
        val isFestal = ordo?.rank?.let { it >= 2.0 } ?: false
        var assembled = officeAssembler.assemble(template, ctx, isFestal)
        if (ordo != null) {
            if (ordo.winner == "sanctoral") {
                // Office layering (each later layer wins): commune fallback,
                // then a borrowed feast's Office (`ex Sancti/...`), then the
                // saint's own proper on top.
                val key = ordo.winnerKey
                val code = saintCommune[key] ?: saintCommune[key.take(5)]
                val commune = code?.let { communeOffice[it] }
                if (commune != null) {
                    assembled = applyProperOverrides(assembled, commune)
                }
                val inheritSource = saintOfficeInherit[key] ?: saintOfficeInherit[key.take(5)]
                val inherited = inheritSource?.let { sanctoralPropers[it] }
                if (inherited != null) {
                    assembled = applyProperOverrides(assembled, inherited)
                }
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

    private val psalmToAntiphonKey = mapOf(
        "laudes.psalm1" to "laudes.antiphon.psalm1",
        "laudes.psalm2" to "laudes.antiphon.psalm2",
        "laudes.psalm3" to "laudes.antiphon.psalm3",
        "laudes.canticle1" to "laudes.antiphon.psalm4",
        "laudes.psalm4" to "laudes.antiphon.psalm5",
        "vesperae.psalm1" to "vesperae.antiphon.psalm1",
        "vesperae.psalm2" to "vesperae.antiphon.psalm2",
        "vesperae.psalm3" to "vesperae.antiphon.psalm3",
        "vesperae.psalm4" to "vesperae.antiphon.psalm4",
        "vesperae.psalm5" to "vesperae.antiphon.psalm5",
    )

    private fun applyProperOverrides(hour: Hour, overrides: Map<String, Hour.Part>): Hour {
        val updatedParts = hour.parts.map { part ->
            val key = part.variationKey
            if (key != null && overrides.containsKey(key)) return@map overrides[key]!!
            // The Little Chapter is shared across Lauds, Terce, and Vespers;
            // inherit capitulum_laudes when those slots have no explicit override.
            if ((key == "vesperae.capitulum" || key == "tertia.capitulum") &&
                overrides.containsKey("capitulum_laudes")) {
                return@map overrides["capitulum_laudes"]!!
            }
            // Proper per-psalm antiphons: set antiphonLat/antiphonEng on the
            // psalm part without replacing the whole part (psalm text/ref).
            if (key != null) {
                val antKey = psalmToAntiphonKey[key]
                if (antKey != null) {
                    val antPart = overrides[antKey]
                    if (antPart != null) {
                        return@map part.copy(
                            antiphonLat = antPart.lat,
                            antiphonEng = antPart.eng,
                        )
                    }
                }
            }
            if (part.type == "collect" && overrides.containsKey("collect")) return@map overrides["collect"]!!
            part
        }
        return hour.copy(parts = updatedParts)
    }

    fun mysterySet(slug: String): MysterySetData? =
        mysterySets.firstOrNull { it.slug == slug }

    fun prayer(slug: String): Prayer? =
        prayers.firstOrNull { it.slug == slug }

    /** Looks up a saint by slug (used by deep-link navigation). */
    fun saint(slug: String): Saint? =
        saints.firstOrNull { it.slug == slug }

    /** Looks up a reference (or calendar) entry by slug (used by deep-link navigation). */
    fun referenceEntry(slug: String): ReferenceEntry? =
        reference.firstOrNull { it.slug == slug }

    /**
     * Looks up a Mass proper by slug across the full combined corpus, which is
     * what the search index targets ([allPropers]). Falls back to the legacy-only
     * [proper] set. Mirrors iOS ContentStore.anyProper(slug:).
     */
    fun anyProper(slug: String): MassProper? =
        allPropers.firstOrNull { it.slug == slug } ?: proper(slug)

    fun prayers(category: String): List<Prayer> =
        prayers.filter { it.category == category }

    // ---- Canon variant accessor ----

    /**
     * Returns the Latin/English pair for a Canon variant insertion.
     * [type] is "communicantes" or "hanc_igitur"; [key] is the feast key
     * (e.g. "easter", "pentecost", "christmas", "epiphany", "ascension").
     */
    fun canonVariant(type: String, key: String): Pair<String, String>? {
        val group = canonVariants[type] ?: return null
        val entry = group[key] ?: return null
        val lat = entry["lat"] ?: return null
        val eng = entry["eng"] ?: return null
        return lat to eng
    }

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
