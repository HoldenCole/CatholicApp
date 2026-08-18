package com.lampstandhq.introibo.data.content

import android.content.Context
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.LiturgicalSeason
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.VernacularLanguage
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

    // JVM test seam: when set, load() reads the SAME asset files from this
    // directory instead of Android assets, so unit tests can run the real
    // office pipeline (hourForDate and everything under it) without a
    // Context. Never used by the app.
    private var fileRoot: java.io.File? = null
    private var filesInitialized = false

    /** Initialise from a directory of asset files (JVM tests only). */
    internal fun initFromDirectory(dir: java.io.File) {
        if (::appContext.isInitialized || filesInitialized) return
        fileRoot = dir
        filesInitialized = true
        loadAll()
    }

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
    internal var communeOffice: Map<String, Map<String, Hour.Part>> = emptyMap()
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
        if (filesInitialized) return
        loadAll()
    }

    private fun loadAll() {
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

        psalterWeeklyData = load("psalter_weekly.json") ?: emptyMap()
        hymnsSeasonalData = load("hymns_seasonal.json") ?: emptyMap()
        temporalData = load("temporal_propers.json") ?: emptyMap()
        psalterTextData = load("psalter.json") ?: emptyMap()

        rebuildOfficeAssembler()
    }

    // Retained so the office assembler can be rebuilt when the vernacular
    // overlay changes (the maps are shared by reference, not copied).
    internal var psalterWeeklyData: Map<String, Map<String, Hour.Part>> = emptyMap()
    internal var hymnsSeasonalData: Map<String, Map<String, Hour.Part>> = emptyMap()
    internal var temporalData: Map<String, Map<String, Hour.Part>> = emptyMap()
    internal var psalterTextData: Map<String, Map<String, List<String>>> = emptyMap()

    private fun rebuildOfficeAssembler() {
        officeAssembler = OfficeAssembler(
            weeklyPsalter = psalterWeeklyData,
            seasonalHymns = hymnsSeasonalData,
            temporalPropers = temporalData,
            marianAntiphons = marianAntiphons,
            psalter = psalterTextData,
        )
    }

    // ---- Vernacular (Spanish overlay) ----

    // Overlay schemas — spanish-translation/*.json, bundled as *_es.json.
    // Each keys the source file's slug to Spanish replacements; anything
    // absent (or misaligned) keeps the English, so partial coverage is safe.
    @kotlinx.serialization.Serializable
    private data class PrayerES(
        val title_es: String,
        val note_es: String? = null,
        val lines_es: List<String>,
    )

    @kotlinx.serialization.Serializable
    private data class MarianAntiphonES(
        val title_es: String,
        val body_es: String,
    )

    @kotlinx.serialization.Serializable
    private data class HourES(
        val name_es: String,
        val time_es: String,
        val intro_es: String,
    )

    @kotlinx.serialization.Serializable
    private data class PsalterES(
        val lines: List<String>,
    )

    @kotlinx.serialization.Serializable
    private data class HourPartES(
        val eng: String? = null,
        val engR: String? = null,
        val v1Eng: String? = null,
        val r1Eng: String? = null,
        val v2Eng: String? = null,
        val r2Eng: String? = null,
        val antiphonEng: String? = null,
        val verses: List<String?>? = null,
    )

    @kotlinx.serialization.Serializable
    private data class CourseES(
        val title_es: String,
        val intro_es: String,
        val sections_es: List<SectionES>,
    ) {
        @kotlinx.serialization.Serializable
        data class SectionES(
            val label_es: String? = null,
            val html_es: String? = null,
            val note_es: String? = null,
            val items_es: List<CardES>? = null,
        )

        @kotlinx.serialization.Serializable
        data class CardES(
            val eng_es: String? = null,
            val phon_es: String? = null,
        )
    }

    @kotlinx.serialization.Serializable
    private data class ReferenceES(
        val title_es: String,
        val summary_es: String,
        val history_es: String? = null,
        val practice_es: String? = null,
        val notes_es: String? = null,
        val scripture_eng_es: String? = null,
    )

    @kotlinx.serialization.Serializable
    private data class SaintES(
        val name_es: String,
        val title_es: String,
        val quote_es: String,
        val penance_es: String? = null,
        val sections_es: List<SectionES>,
        val prayers_es: List<SaintPrayerES>? = null,
    ) {
        @kotlinx.serialization.Serializable
        data class SectionES(
            val eng_es: String,
            val practices_es: List<PracticeES>,
        )

        @kotlinx.serialization.Serializable
        data class PracticeES(
            val t_es: String,
            val d_es: String,
        )

        @kotlinx.serialization.Serializable
        data class SaintPrayerES(
            val title_es: String,
            val eng_es: String,
            val note_es: String? = null,
        )
    }

    // missal_es.json is PARTIAL by design — the Ordinary translates section
    // by section (the Canon first); uncovered sections keep their English.
    @kotlinx.serialization.Serializable
    private data class MissalLineES(
        val eng_es: String,
        val rubric_es: String? = null,
    )

    @kotlinx.serialization.Serializable
    private data class MissalSectionES(
        val english_es: String? = null,
        val body_es: List<MissalLineES>,
    )

    private var appliedVernacular: VernacularLanguage = VernacularLanguage.ENGLISH

    // UI-chrome strings for the active vernacular; empty when English.
    // ONLY the English half of a dual "Latin · English" label ever goes
    // through here — the Latin half is a literal at the call site and is
    // identical in every vernacular. (Screens recompose on language change
    // via the key(vernacular) wrapper in MainActivity.)
    private var uiStringsES: Map<String, String> = emptyMap()

    /** The vernacular form of a piece of UI chrome; [en] when not covered. */
    fun uiString(key: String, en: String): String = uiStringsES[key] ?: en

    /** The vernacular whose overlay is currently applied to the store. */
    val currentVernacular: VernacularLanguage get() = appliedVernacular

    /**
     * Switches the vernacular side of prayers, Marian antiphons, and hour
     * metadata. Reloads the pristine sources first (so es→en restores the
     * English), rebuilds the office assembler (Compline's antiphon comes
     * from its copy), and drops the search/link caches built on the old
     * text. No-op when [lang] is already applied.
     */
    fun applyVernacular(lang: VernacularLanguage) {
        if (lang == appliedVernacular) return
        appliedVernacular = lang

        prayers = load("prayers.json") ?: emptyList()
        hours = load("hours.json") ?: emptyList()
        marianAntiphons = load("marian_antiphons.json") ?: emptyList()
        missal = load("missal.json") ?: emptyList()
        canonVariants = load("canon_variants.json") ?: emptyMap()
        ordoNamesEn = load("ordo_names_en.json") ?: emptyMap()
        missalTempora = load("missal_tempora.json") ?: emptyMap()
        missalSanctoral = load("missal_sanctoral.json") ?: emptyMap()
        stations = load("stations.json") ?: emptyList()
        saints = load("saints.json") ?: emptyList()
        reference = load("reference.json") ?: emptyList()
        courses = load("courses.json") ?: emptyList()
        psalterTextData = load("psalter.json") ?: emptyMap()
        psalterWeeklyData = load("psalter_weekly.json") ?: emptyMap()
        communeOffice = load("commune_office.json") ?: emptyMap()
        temporalData = load("temporal_propers.json") ?: emptyMap()
        hymnsSeasonalData = load("hymns_seasonal.json") ?: emptyMap()

        uiStringsES = emptyMap()

        if (lang == VernacularLanguage.SPANISH) {
            // Feast names: Spanish wins, missing keys keep their English.
            load<Map<String, String>>("ordo_names_es.json")?.let { es ->
                ordoNamesEn = ordoNamesEn + es
            }
            uiStringsES = (load<Map<String, String>>("ui_strings_es.json") ?: emptyMap())
                .filterKeys { !it.startsWith("_") }
            // Mass propers (tranche-based import from the DO Espanol tree):
            // per-field vernacular replacement; uncovered days and the
            // deferred scripture fields keep their English.
            load<Map<String, Map<String, String>>>("missal_propers_es.json")?.let { es ->
                val overlay: (Map<String, MissalProperEntry>) -> Map<String, MissalProperEntry> = { map ->
                    map.mapValues { (key, entry) ->
                        val fields = es[key] ?: return@mapValues entry
                        entry.copy(
                            introitus = fields["introitus"]?.let { entry.introitus?.copy(eng = it) } ?: entry.introitus,
                            oratio = fields["oratio"]?.let { entry.oratio?.copy(eng = it) } ?: entry.oratio,
                            graduale = fields["graduale"]?.let { entry.graduale?.copy(eng = it) } ?: entry.graduale,
                            offertorium = fields["offertorium"]?.let { entry.offertorium?.copy(eng = it) } ?: entry.offertorium,
                            secreta = fields["secreta"]?.let { entry.secreta?.copy(eng = it) } ?: entry.secreta,
                            communio = fields["communio"]?.let { entry.communio?.copy(eng = it) } ?: entry.communio,
                            postcommunio = fields["postcommunio"]?.let { entry.postcommunio?.copy(eng = it) } ?: entry.postcommunio,
                        )
                    }
                }
                missalTempora = overlay(missalTempora)
                missalSanctoral = overlay(missalSanctoral)
            }
            // Mass Scripture readings (Torres Amat, composed per pericope):
            // same per-field replacement, kept in its own file because the
            // corpus and its provenance differ from the propers.
            load<Map<String, Map<String, String>>>("missal_readings_es.json")?.let { es ->
                val overlay: (Map<String, MissalProperEntry>) -> Map<String, MissalProperEntry> = { map ->
                    map.mapValues { (key, entry) ->
                        val fields = es[key] ?: return@mapValues entry
                        entry.copy(
                            lectio = fields["lectio"]?.let { entry.lectio?.copy(eng = it) } ?: entry.lectio,
                            evangelium = fields["evangelium"]?.let { entry.evangelium?.copy(eng = it) } ?: entry.evangelium,
                        )
                    }
                }
                missalTempora = overlay(missalTempora)
                missalSanctoral = overlay(missalSanctoral)
            }
            // Stations of the Cross: title, meditation, and the received
            // Spanish Stabat Mater verse (Latin title and verse untouched).
            load<Map<String, Map<String, String>>>("stations_es.json")?.let { es ->
                stations = stations.map { s ->
                    val o = es[s.station] ?: return@map s
                    s.copy(
                        title = o["title_es"] ?: s.title,
                        med = o["med_es"] ?: s.med,
                        stabatEng = o["stabat_es"] ?: s.stabatEng,
                    )
                }
            }
            // The Psalter (Torres Amat, translated from the Vulgate):
            // line-aligned replacement of each psalm's eng array, then the
            // same lines fan out to the weekly psalter (null keeps
            // English). The office assembler is rebuilt AFTER this
            // overlay, so the Spanish flows into every assembled hour.
            load<Map<String, PsalterES>>("psalter_es.json")?.let { es ->
                psalterTextData = psalterTextData.mapValues { (name, entry) ->
                    val o = es[name] ?: return@mapValues entry
                    val eng = entry["eng"]
                    if (eng != null && eng.size == o.lines.size) {
                        entry + ("eng" to o.lines)
                    } else {
                        entry
                    }
                }
            }
            load<Map<String, Map<String, List<String?>>>>("psalter_weekly_es.json")?.let { es ->
                psalterWeeklyData = psalterWeeklyData.mapValues { (day, parts) ->
                    val dayEs = es[day] ?: return@mapValues parts
                    parts.mapValues { (key, part) ->
                        val lines = dayEs[key] ?: return@mapValues part
                        val verses = part.verses
                        if (verses != null && verses.size == lines.size) {
                            part.copy(
                                verses = verses.mapIndexed { i, vv ->
                                    lines[i]?.let { vv.copy(eng = it) } ?: vv
                                },
                            )
                        } else {
                            part
                        }
                    }
                }
            }
            // The Office commons (tranche O3): same per-part replacement
            // as the hours, keyed by commune code and field key.
            load<Map<String, Map<String, HourPartES>>>("commune_office_es.json")?.let { es ->
                communeOffice = communeOffice.mapValues { (code, entry) ->
                    val fields = es[code] ?: return@mapValues entry
                    entry.mapValues { (fkey, part) ->
                        val o = fields[fkey] ?: return@mapValues part
                        part.copy(
                            eng = o.eng ?: part.eng,
                            engR = o.engR ?: part.engR,
                            v1Eng = o.v1Eng ?: part.v1Eng,
                            r1Eng = o.r1Eng ?: part.r1Eng,
                            v2Eng = o.v2Eng ?: part.v2Eng,
                            r2Eng = o.r2Eng ?: part.r2Eng,
                            antiphonEng = o.antiphonEng ?: part.antiphonEng,
                            verses = if (part.verses != null && o.verses != null &&
                                o.verses.size == part.verses.size
                            ) {
                                part.verses.mapIndexed { j, vv ->
                                    o.verses[j]?.let { vv.copy(eng = it) } ?: vv
                                }
                            } else {
                                part.verses
                            },
                        )
                    }
                }
            }
            // The temporal propers (tranche O4): non-lesson fields —
            // antiphons, responsories, collects, versicles, hymns.
            load<Map<String, Map<String, HourPartES>>>("temporal_propers_es.json")?.let { es ->
                temporalData = temporalData.mapValues { (code, entry) ->
                    val fields = es[code] ?: return@mapValues entry
                    entry.mapValues { (fkey, part) ->
                        val o = fields[fkey] ?: return@mapValues part
                        part.copy(
                            eng = o.eng ?: part.eng,
                            engR = o.engR ?: part.engR,
                            v1Eng = o.v1Eng ?: part.v1Eng,
                            r1Eng = o.r1Eng ?: part.r1Eng,
                            v2Eng = o.v2Eng ?: part.v2Eng,
                            r2Eng = o.r2Eng ?: part.r2Eng,
                            antiphonEng = o.antiphonEng ?: part.antiphonEng,
                            verses = if (part.verses != null && o.verses != null &&
                                o.verses.size == part.verses.size
                            ) {
                                part.verses.mapIndexed { j, vv ->
                                    o.verses[j]?.let { vv.copy(eng = it) } ?: vv
                                }
                            } else {
                                part.verses
                            },
                        )
                    }
                }
            }
            // The seasonal hymns (tranche O6): traditional verse
            // translations, plus the Compline canticle antiphons.
            load<Map<String, Map<String, HourPartES>>>("hymns_seasonal_es.json")?.let { es ->
                hymnsSeasonalData = hymnsSeasonalData.mapValues { (season, entry) ->
                    val fields = es[season] ?: return@mapValues entry
                    entry.mapValues { (fkey, part) ->
                        val o = fields[fkey] ?: return@mapValues part
                        part.copy(
                            eng = o.eng ?: part.eng,
                            antiphonEng = o.antiphonEng ?: part.antiphonEng,
                        )
                    }
                }
            }
            // Schola Latina courses: localized (not merely translated) for
            // Spanish speakers — the lessons address a Spanish ear and the
            // phonetic respellings are re-keyed to Spanish orthography.
            // Aligned by section/item index; the Latin words are untouched.
            load<Map<String, CourseES>>("courses_es.json")?.let { es ->
                courses = courses.map { c ->
                    val o = es[c.slug] ?: return@map c
                    c.copy(
                        title = o.title_es,
                        intro = o.intro_es,
                        sections = if (o.sections_es.size == c.sections.size) {
                            c.sections.mapIndexed { i, sec ->
                                val se = o.sections_es[i]
                                sec.copy(
                                    label = if (sec.label != null) se.label_es ?: sec.label else sec.label,
                                    html = if (sec.html != null) se.html_es ?: sec.html else sec.html,
                                    note = if (sec.note != null) se.note_es ?: sec.note else sec.note,
                                    items = if (sec.items != null && se.items_es != null &&
                                        se.items_es.size == sec.items.size
                                    ) {
                                        sec.items.mapIndexed { j, card ->
                                            val ce = se.items_es[j]
                                            card.copy(
                                                eng = if (card.eng != null) ce.eng_es ?: card.eng else card.eng,
                                                phon = if (card.phon != null) ce.phon_es ?: card.phon else card.phon,
                                            )
                                        }
                                    } else {
                                        sec.items
                                    },
                                )
                            }
                        } else {
                            c.sections
                        },
                    )
                }
            }
            // Reference encyclopedia: English-side prose per slug (title,
            // summary, history, practice, notes, and the scripture quote's
            // English half; the Latin names, category labels, refs, and
            // Latin quotes stay).
            load<Map<String, ReferenceES>>("reference_es.json")?.let { es ->
                reference = reference.map { e ->
                    val o = es[e.slug] ?: return@map e
                    e.copy(
                        title = o.title_es,
                        summary = o.summary_es,
                        history = if (e.history != null) o.history_es ?: e.history else e.history,
                        practice = if (e.practice != null) o.practice_es ?: e.practice else e.practice,
                        notes = if (e.notes != null) o.notes_es ?: e.notes else e.notes,
                        scripture = if (e.scripture != null && o.scripture_eng_es != null) {
                            e.scripture.copy(eng = o.scripture_eng_es)
                        } else {
                            e.scripture
                        },
                    )
                }
            }
            // Saints' devotional programs: English-side fields per slug,
            // aligned by section/practice/prayer index (the Latin section
            // labels and Latin prayer texts are untouched; a count mismatch
            // keeps English).
            load<Map<String, SaintES>>("saints_es.json")?.let { es ->
                saints = saints.map { s ->
                    val o = es[s.slug] ?: return@map s
                    s.copy(
                        name = o.name_es,
                        title = o.title_es,
                        quote = o.quote_es,
                        penance = if (s.penance != null) o.penance_es ?: s.penance else s.penance,
                        sections = if (o.sections_es.size == s.sections.size) {
                            s.sections.mapIndexed { i, sec ->
                                val se = o.sections_es[i]
                                sec.copy(
                                    eng = se.eng_es,
                                    practices = if (se.practices_es.size == sec.practices.size) {
                                        sec.practices.mapIndexed { j, p ->
                                            p.copy(t = se.practices_es[j].t_es, d = se.practices_es[j].d_es)
                                        }
                                    } else {
                                        sec.practices
                                    },
                                )
                            }
                        } else {
                            s.sections
                        },
                        prayers = if (s.prayers != null && o.prayers_es != null &&
                            o.prayers_es.size == s.prayers.size
                        ) {
                            s.prayers.mapIndexed { i, p ->
                                val pe = o.prayers_es[i]
                                p.copy(
                                    title = pe.title_es,
                                    eng = pe.eng_es,
                                    note = if (p.note != null) pe.note_es ?: p.note else p.note,
                                )
                            }
                        } else {
                            s.prayers
                        },
                    )
                }
            }
            load<Map<String, PrayerES>>("prayers_es.json")?.let { es ->
                prayers = prayers.map { p ->
                    val o = es[p.slug] ?: return@map p
                    p.copy(
                        eng = o.title_es,
                        note = if (p.note != null) o.note_es ?: p.note else p.note,
                        lines = if (o.lines_es.size == p.lines.size) {
                            p.lines.mapIndexed { i, line -> line.copy(eng = o.lines_es[i]) }
                        } else {
                            p.lines
                        },
                    )
                }
            }
            load<Map<String, MarianAntiphonES>>("marian_antiphons_es.json")?.let { es ->
                marianAntiphons = marianAntiphons.map { a ->
                    val o = es[a.slug] ?: return@map a
                    a.copy(eng = o.title_es, engBody = o.body_es)
                }
            }
            load<Map<String, HourES>>("hours_es.json")?.let { es ->
                hours = hours.map { h ->
                    val o = es[h.slug] ?: return@map h
                    h.copy(eng = o.name_es, time = o.time_es, intro = o.intro_es)
                }
            }
            // The ordinary of the hours (Office tranche O2): per-part
            // English-side replacement, indexed by part position —
            // versicles, blessings, hymns, antiphons, readings,
            // responsories, collects, and the psalm/canticle verses
            // (null keeps English).
            load<Map<String, Map<String, HourPartES>>>("hours_parts_es.json")?.let { es ->
                hours = hours.map { h ->
                    val hp = es[h.slug] ?: return@map h
                    h.copy(
                        parts = h.parts.mapIndexed { i, p ->
                            val o = hp[i.toString()] ?: return@mapIndexed p
                            p.copy(
                                eng = o.eng ?: p.eng,
                                engR = o.engR ?: p.engR,
                                v1Eng = o.v1Eng ?: p.v1Eng,
                                r1Eng = o.r1Eng ?: p.r1Eng,
                                v2Eng = o.v2Eng ?: p.v2Eng,
                                r2Eng = o.r2Eng ?: p.r2Eng,
                                antiphonEng = o.antiphonEng ?: p.antiphonEng,
                                verses = if (p.verses != null && o.verses != null &&
                                    o.verses.size == p.verses.size
                                ) {
                                    p.verses.mapIndexed { j, vv ->
                                        o.verses[j]?.let { vv.copy(eng = it) } ?: vv
                                    }
                                } else {
                                    p.verses
                                },
                            )
                        },
                    )
                }
            }
            load<Map<String, MissalSectionES>>("missal_es.json")?.let { es ->
                missal = missal.map { s ->
                    val o = es[s.slug] ?: return@map s
                    if (o.body_es.size != s.body.size) return@map s
                    s.copy(
                        english = o.english_es ?: s.english,
                        body = s.body.mapIndexed { i, line ->
                            line.copy(
                                eng = o.body_es[i].eng_es,
                                rubric = if (line.rubric != null) {
                                    o.body_es[i].rubric_es ?: line.rubric
                                } else {
                                    line.rubric
                                },
                            )
                        },
                    )
                }
            }
            load<Map<String, Map<String, Map<String, String>>>>("canon_variants_es.json")?.let { es ->
                canonVariants = canonVariants.mapValues { (group, entries) ->
                    entries.mapValues { (key, entry) ->
                        val e = es[group]?.get(key)?.get("eng_es")
                        if (e != null) entry + ("eng" to e) else entry
                    }
                }
            }
        }

        rebuildOfficeAssembler()
        synchronized(this) {
            _searchIndex = null
            _linkGraph = null
            _allPropers = null
        }
    }

    // ---- Search index (Phase 1: index core) ----
    //
    // Built lazily on first access. Owned here so the whole app shares one
    // folded corpus. Mirror: iOS ContentStore.searchIndex. Cached in a
    // resettable holder (not `by lazy`) so a vernacular switch can drop the
    // corpus built on the old text; call prepareSearchIndex() on a background
    // thread at launch to avoid blocking the first reader.

    @Volatile
    private var _searchIndex: com.lampstandhq.introibo.data.search.SearchIndex? = null

    val searchIndex: com.lampstandhq.introibo.data.search.SearchIndex
        get() = _searchIndex ?: synchronized(this) {
            _searchIndex
                ?: com.lampstandhq.introibo.data.search.SearchIndex.build(this)
                    .also { _searchIndex = it }
        }

    /** Eagerly builds the search index off the main thread. Idempotent. */
    fun prepareSearchIndex() {
        Thread {
            try {
                searchIndex
            } catch (t: Throwable) {
                android.util.Log.e("INTROIBO_START", "search index build failed", t)
            }
        }.start()
    }

    // ---- Link graph (Phase 3: contextual-links reverse index) ----
    //
    // The bidirectional "Referenced By" reverse index. Built lazily on first
    // access, exactly like searchIndex. Owned here so the whole app shares one
    // graph. Mirror: iOS ContentStore.linkGraph.
    // `by lazy` is thread-safe (LazyThreadSafetyMode.SYNCHRONIZED) by default;
    // call prepareLinkGraph() on a background thread at launch to avoid blocking
    // the first reader.

    @Volatile
    private var _linkGraph: com.lampstandhq.introibo.data.links.LinkGraph? = null

    val linkGraph: com.lampstandhq.introibo.data.links.LinkGraph
        get() = _linkGraph ?: synchronized(this) {
            _linkGraph
                ?: com.lampstandhq.introibo.data.links.LinkGraph.build(this)
                    .also { _linkGraph = it }
        }

    /** Eagerly builds the link graph off the main thread. Idempotent. */
    fun prepareLinkGraph() {
        Thread {
            try {
                linkGraph
            } catch (t: Throwable) {
                android.util.Log.e("INTROIBO_START", "link graph build failed", t)
            }
        }.start()
    }

    // ---- Convenience lookups ----

    fun proper(slug: String): MassProper? =
        propers.firstOrNull { it.slug == slug }

    // Resettable cache (not `by lazy`): a vernacular switch overlays
    // missalTempora and must rebuild the derived propers.
    @Volatile
    private var _allPropers: List<MassProper>? = null

    val allPropers: List<MassProper>
        get() = _allPropers ?: synchronized(this) {
            _allPropers ?: buildAllPropers().also { _allPropers = it }
        }

    private fun buildAllPropers(): List<MassProper> {
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
        return combined.values.sortedBy { it.slug }
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
        inheritedTemporalKey(key, rite)?.let { parent ->
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

        // Ferias whose temporal key has no weekday form (the early-January
        // "nat08".."nat11" days) repeat the preceding Sunday's Mass — find
        // that Sunday by DATE and resolve its own formulary. One hop only:
        // the recursive call lands on a Sunday and never reaches this branch.
        if (date.dayOfWeek != java.time.DayOfWeek.SUNDAY) {
            val sunday = date.minusDays((date.dayOfWeek.value % 7).toLong())
            return properForDate(sunday, rite)
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

    private fun inheritedTemporalKey(key: String, rite: MissalRite): String? {
        // Ascension octave (Pasc5-5 through Pasc6-4) inherits from Pasc5-4.
        // The octave exists only in the pre-1955 books; 1955/1962 ferias in
        // that range keep their own (per-annum) formulary.
        if (rite != MissalRite.PRE_1955) return null
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
        return try {
            hourForDate(slug, java.time.LocalDate.now(), rite)
        } catch (t: Throwable) {
            // Log but don't crash — mirrors load()'s philosophy. A data edge
            // case in one day's Office must not take down the whole app.
            android.util.Log.e("INTROIBO_OFFICE", "hourForToday failed for slug=$slug", t)
            null
        }
    }

    /**
     * The full office pipeline for any [date] (assembly + proper layers +
     * commemoration). Throws on data edge cases — hourForToday catches; the
     * QA sweep wants the exception.
     */
    internal fun hourForDate(slug: String, date: java.time.LocalDate, rite: MissalRite = MissalRite.RITE_1962): Hour? {
        val template = hour(slug) ?: return null
        // Build the context with the caller's rite — ctx.properSlug feeds the
        // Preces Feriales gate in OfficeAssembler (iOS reads the rite here too).
        val ctx = LiturgicalContext.forDate(date, rite = rite)
        val ordo = ordoForDate(ctx.date, rite)
        // Festal (Sunday) psalm scheme at Lauds & Vespers belongs to I/II
        // class feasts only (rank >= 5). Since Divino Afflatu (1911) — and in
        // the 1962 books — III class feasts and ferias pray the psalms of the
        // occurring weekday. The old rank >= 2.0 gate wrongly gave most
        // weekdays the Sunday psalms.
        // 1955/pre-1955 keep the Divino Afflatu rule: every double and
        // semidouble (rank >= 3) prays the festal scheme; 1962 restricts it
        // to I/II class (rank >= 5).
        // Privileged ferias (Ash Wednesday, Ember days, the January ferias)
        // carry HIGH ranks so the calendar wins precedence with them — but
        // their OFFICE is still ferial: weekday psalms, one nocturn, ferial
        // preces. Detect them by name, not rank. The Triduum is excepted:
        // its Matins (Tenebrae) keeps three nocturns.
        val isTriduum = ctx.temporalKey in setOf("quad6-4", "quad6-5", "quad6-6")
        val ferialOffice = ordo == null || (
            ordo.winner == "temporal" && !isTriduum &&
                (ordo.name.startsWith("Feria") || ordo.name.startsWith("Sabbato") ||
                    ordo.name.startsWith("Die "))
            )

        val festalThreshold = if (rite == MissalRite.RITE_1962) 5.0 else 3.0
        val isFestal = !ferialOffice && (ordo?.rank?.let { it >= festalThreshold } ?: false)
        // Compline keeps the Sunday psalms only on Sundays and I/II-class
        // feasts (rank >= 5); III class and below use the ferial Compline.
        val festalCompline = ctx.isSunday ||
            (!ferialOffice && (ordo?.rank?.let { it >= 5.0 } ?: false))
        // The Little Hours keep the Sunday psalms (Ps 118) only on Sundays
        // and I-class feasts (rank >= 6); all else uses the ferial psalms.
        val festalLittleHours = ctx.isSunday ||
            (!ferialOffice && (ordo?.rank?.let { it >= 6.0 } ?: false))

        // Matins (1960 rubrics): 3 nocturns / 9 lessons only for I- and II-class
        // feasts (sanctoral rank >= 5, or a temporal I-class feast on a weekday
        // such as Corpus Christi). All Sundays, III-class feasts, and ferias use
        // a single nocturn of 9 psalms and 3 lessons.
        val isClassIorII = when {
            ordo == null -> false
            // A ferial office is one nocturn no matter how privileged the
            // feria's precedence rank is (Ash Wednesday, Ember days).
            ferialOffice -> false
            // Pre-1960 rubrics: all doubles/semidoubles (rank >= 3) and all
            // Sundays have 3 nocturns / 9 lessons; only ferias and simples
            // use the single nocturn.
            rite != MissalRite.RITE_1962 && (ordo.rank >= 3.0 || ctx.isSunday) -> true
            ordo.winner == "sanctoral" && ordo.rank >= 5.0 -> true
            ordo.rank >= 6.0 && !ctx.isSunday -> true
            else -> false
        }
        val matinsNocturns = if (isClassIorII) 3 else 1
        val matinsTeDeum = computeMatinsTeDeum(ctx, ordo, rite)

        // Last-resort day collect: the day's Mass collect via the Missal
        // pipeline, whose resolution (preceding Sunday, stub redirects,
        // resumed Sundays, early-January ferias) is the app's single source
        // of truth for "the collect of the day".
        val fallbackCollect = properForDate(date, rite)?.collect?.let { c ->
            Hour.Part(type = "collect", label = "Collect", lat = c.lat, eng = c.eng, variationKey = "oratio")
        }

        var assembled = officeAssembler.assemble(template, ctx, isFestal, festalCompline, festalLittleHours, matinsNocturns, matinsTeDeum, rite, fallbackCollect, ferialOffice)

        // Every layered dict goes through the hour-aware semantic remap
        // (canticle antiphons vs. nocturn slots, psalm-antiphon lists,
        // versicle numbering, spelling aliases) — the raw DO keys collide
        // with the template's variationKeys and would otherwise silently
        // miss (or worse, land on the wrong slot).
        fun layer(overrides: Map<String, Hour.Part>) {
            val remapped = OfficeAssembler
                .remapProperOverrides(overrides, template.slug)
                .toMutableMap()
            // 1960 rubrics: a III-class feast's Matins has ONE nocturn — two
            // Scripture lessons of the feria and the saint's contracted
            // legend as the third. DO ships the contraction as Lectio94 /
            // Lectio93; failing that, join the legend lessons 4-6. Without
            // this, the saint's lessons target the lectio4-9 slots that the
            // 1-nocturn structure no longer has.
            if (template.slug == "matutinum" && matinsNocturns == 1 &&
                "lectio3" !in remapped
            ) {
                contractedLesson(remapped)?.let { remapped["lectio3"] = it }
            }
            assembled = applyProperOverrides(assembled, remapped)
        }

        if (ordo != null) {
            if (ordo.winner == "sanctoral") {
                // Office layering (each later layer wins): commune fallback,
                // then a borrowed feast's Office (`ex Sancti/...`), then the
                // saint's own proper on top.
                val key = ordo.winnerKey
                val code = saintCommune[key] ?: saintCommune[key.take(5)]
                val commune = code?.let { communeOffice[it] }
                if (commune != null) {
                    layer(commune)
                }
                val inheritSource = saintOfficeInherit[key] ?: saintOfficeInherit[key.take(5)]
                val inherited = inheritSource?.let { sanctoralPropers[it] }
                if (inherited != null) {
                    layer(inherited)
                }
                val saint = sanctoralPropers[ordo.winnerKey]
                if (saint != null) {
                    layer(saint)
                }
                // Pre-1955 old-rite variant of the saint's Office ("<key>o"),
                // e.g. the festive Epiphany-octave lessons the 1960 books
                // reduced to ferial commemorations.
                if (rite == MissalRite.PRE_1955) {
                    val oSaint = sanctoralPropers[ordo.winnerKey + "o"]
                    if (oSaint != null) {
                        layer(oSaint)
                    }
                }
            } else {
                val temporalKey = ordo.temporal
                if (temporalKey != null) {
                    val tempOverrides = officeAssembler.temporalPropers[temporalKey]
                    if (tempOverrides != null) {
                        layer(tempOverrides)
                    }
                }
            }
        }

        // Pre-1955 old-rite Office variants: DO ships "<key>o" overlays (extra
        // Matins lessons etc. for the octaves the later books suppressed).
        // Layer them over the base temporal content.
        if (rite == MissalRite.PRE_1955) {
            val oKey = ctx.temporalKey?.let { it + "o" }
            val oOverrides = oKey?.let { officeAssembler.temporalPropers[it] }
            if (oOverrides != null) {
                layer(oOverrides)
            }
        }

        // Dec 17-23 ("O Antiphon" days): override the Little Hours antiphons
        // with date-specific ones (these change daily, unlike the per-week
        // Advent antiphons applied by the temporal key above).
        if (ctx.season == LiturgicalSeason.ADVENT &&
            ctx.date.monthValue == 12 && ctx.date.dayOfMonth in 17..23) {
            val dateOverrides = officeAssembler.temporalPropers["adv-12-${ctx.date.dayOfMonth}"]
            if (dateOverrides != null) {
                layer(dateOverrides)
            }
        }

        // Commemoration of the concurring office: its antiphon, versicle and
        // collect follow the collect of the day at Lauds (all rites) and at
        // Vespers in the pre-1960 rites, which kept most Vespers
        // commemorations. This is how a suppressed feria, a commemorated
        // saint, or an octave day stays present in the day's office.
        val commemKey = ordo?.commemoration
        if (!commemKey.isNullOrEmpty() &&
            (template.slug == "laudes" ||
                (template.slug == "vesperae" && rite != MissalRite.RITE_1962))
        ) {
            val commemData = sanctoralPropers[commemKey]
                ?: officeAssembler.temporalPropers[commemKey]
            if (commemData != null) {
                // A commemorated temporal feria (e.g. the Advent feria on a
                // III-class feast) has no collect of its own — it repeats
                // the Sunday's, like the feria's office would.
                val effective = if ("oratio" in commemData) {
                    commemData
                } else {
                    val sundayOratio = OfficeAssembler.precedingSundayKey(commemKey)
                        ?.let { officeAssembler.temporalPropers[it]?.get("oratio") }
                    if (sundayOratio != null) commemData + ("oratio" to sundayOratio) else commemData
                }
                assembled = insertCommemoration(assembled, effective, template.slug)
            }
        }

        return assembled
    }

    /**
     * Whether the Te Deum is said at Matins (1960 rubrics). Said on Sundays
     * (per-annum and Septuagesima), on all feasts (III class and above), and on
     * days of the Christmas/Easter/Pentecost seasons and their octaves; omitted
     * on ordinary ferias and on all Advent and Lent/Passion days -- except
     * feasts, which keep it even in penitential seasons.
     */
    private fun computeMatinsTeDeum(ctx: LiturgicalContext, ordo: OrdoEntry?, rite: MissalRite = MissalRite.RITE_1962): Boolean {
        // Pre-1960 rubrics: octave days and other festive temporal winners
        // (rank >= 3) also say the Te Deum, not just sanctoral feasts.
        val isFeast = (ordo?.winner == "sanctoral" && (ordo.rank) >= 3.0) ||
            (rite != MissalRite.RITE_1962 && (ordo?.rank ?: 0.0) >= 3.0)
        // Pre-Lent (Septuagesima) counts as penitential for the Te Deum:
        // it is omitted on those Sundays through Lent, kept on feasts.
        val penitential = ctx.season == LiturgicalSeason.ADVENT ||
            ctx.season == LiturgicalSeason.LENT ||
            ctx.season == LiturgicalSeason.PASSION ||
            ctx.temporalKey?.startsWith("quadp") == true
        if (penitential) return isFeast
        if (ctx.isSunday) return true
        if (isFeast) return true
        if (ctx.season == LiturgicalSeason.EASTER || ctx.season == LiturgicalSeason.CHRISTMAS) return true
        return false
    }

    private fun applyProperOverrides(hour: Hour, overrides: Map<String, Hour.Part>): Hour {
        val updatedParts = hour.parts.map { part ->
            val key = part.variationKey
            // Base part: a direct full-part override (rekeyed onto the
            // template's slot so later layers can still address it), else
            // the existing part. (The Triduum supplies both a replacement
            // psalm and its proper antiphon, so apply the antiphon on top of
            // the replacement.)
            val base = if (key != null) {
                (overrides[key] ?: part).copy(variationKey = key)
            } else {
                part
            }
            // Proper per-psalm antiphons: set antiphonLat/antiphonEng on the
            // psalm part without discarding the psalm text/ref. Mapping
            // shared with OfficeAssembler.
            if (key != null) {
                val antKey = OfficeAssembler.PSALM_TO_ANTIPHON_KEY[key]
                val antPart = if (antKey != null) overrides[antKey] else null
                if (antPart != null) {
                    return@map base.copy(antiphonLat = antPart.lat, antiphonEng = antPart.eng)
                }
            }
            if (key != null && overrides.containsKey(key)) return@map base
            // The Little Chapter is shared across Lauds, Terce, and Vespers;
            // inherit capitulum_laudes when those slots have no explicit override.
            if ((key == "vesperae.capitulum" || key == "tertia.capitulum") &&
                overrides.containsKey("capitulum_laudes")) {
                return@map overrides["capitulum_laudes"]!!
            }
            if (part.type == "collect" && overrides.containsKey("collect")) return@map overrides["collect"]!!
            part
        }
        return hour.copy(parts = updatedParts)
    }

    /** QA seam: the collect texts the saint's layers could supply (proper +
     *  pre-1955 "o" variant), or null when the entry carries no collect. */
    internal fun sanctoralOratioForQA(winnerKey: String, rite: MissalRite): List<String>? {
        val texts = listOfNotNull(
            sanctoralPropers[winnerKey]?.get("oratio")?.lat,
            if (rite == MissalRite.PRE_1955) {
                sanctoralPropers[winnerKey + "o"]?.get("oratio")?.lat
            } else {
                null
            },
        )
        return texts.ifEmpty { null }
    }

    /** QA seam: whether commemoration data exists with a resolvable collect. */
    internal fun commemorationHasOratioForQA(key: String): Boolean {
        val data = sanctoralPropers[key] ?: officeAssembler.temporalPropers[key] ?: return false
        if ("oratio" in data) return true
        return OfficeAssembler.precedingSundayKey(key)
            ?.let { officeAssembler.temporalPropers[it]?.containsKey("oratio") } == true
    }

    /**
     * DO's contracted single legend lesson for 1-nocturn feast Matins:
     * Lectio94, else Lectio93, else the legend lessons 4-6 joined.
     */
    private fun contractedLesson(overrides: Map<String, Hour.Part>): Hour.Part? {
        (overrides["lectio94"] ?: overrides["lectio93"])?.let {
            return it.copy(variationKey = "lectio3")
        }
        val legend = listOf("lectio4", "lectio5", "lectio6").mapNotNull { overrides[it] }
        if (legend.isEmpty()) return null
        val engs = legend.mapNotNull { it.eng }
        return legend[0].copy(
            variationKey = "lectio3",
            lat = legend.mapNotNull { it.lat }.joinToString("\n\n"),
            eng = if (engs.isEmpty()) null else engs.joinToString("\n\n"),
        )
    }

    /**
     * Builds and inserts the commemoration block (antiphon -> versicle ->
     * collect) after the day's collect. Pieces the data lacks are omitted;
     * without a collect there is no commemoration to make.
     */
    private fun insertCommemoration(hour: Hour, data: Map<String, Hour.Part>, hourSlug: String): Hour {
        val oratio = data["oratio"] ?: return hour
        val collectIdx = hour.parts.indexOfLast {
            it.variationKey == "oratio" && it.type == "collect"
        }
        if (collectIdx == -1) return hour

        val block = mutableListOf<Hour.Part>()
        block.add(Hour.Part(type = "heading", label = "Commemoratio"))

        // The commemorated office's own canticle antiphon: Benedictus at
        // Lauds (DO Ant 2), Magnificat at Vespers (Ant 3, else Ant 1). The
        // curated communes keep single-line canticle antiphons under
        // ant_laudes / ant_vespera.
        fun singleLine(part: Hour.Part?): Hour.Part? {
            val lat = part?.lat ?: return null
            return if ("\n" in lat) null else part
        }
        val ant = if (hourSlug == "laudes") {
            data["ant_2"] ?: singleLine(data["ant_laudes"])
        } else {
            data["ant_3"] ?: data["ant_1"] ?: singleLine(data["ant_vespera"])
        }
        if (ant != null) {
            block.add(ant.copy(variationKey = null, label = "Antiphon"))
        }

        val versum = if (hourSlug == "laudes") {
            data["versum_2"] ?: data["versum_1"]
        } else {
            data["versum_3"] ?: data["versum_1"]
        }
        if (versum != null) {
            block.add(versum.copy(variationKey = null))
        }

        block.add(oratio.copy(variationKey = null, label = "Oratio"))

        val parts = hour.parts.toMutableList()
        parts.addAll(collectIdx + 1, block)
        return hour.copy(parts = parts)
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
            val root = fileRoot
            val text = if (root != null) {
                java.io.File(root, filename).readText()
            } else {
                appContext.assets.open(filename).bufferedReader().use { it.readText() }
            }
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
