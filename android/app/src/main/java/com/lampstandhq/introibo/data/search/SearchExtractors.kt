package com.lampstandhq.introibo.data.search

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.MissalSection
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.ProperReading
import com.lampstandhq.introibo.data.model.ProperText
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.data.model.strippingEm

// MARK: - SearchExtractors (Phase 1: index core)
//
// Mirror of:
//   Introibo/Data/Search/SearchExtractors.swift
//
// One extractor per content type. Each turns a slice of ContentStore's
// in-memory content into List<SearchDocument>. Extractors are run (and
// partitioned) by SearchIndex.build, so adding a content type is:
//   1. add a ContentType case,
//   2. add an extractor,
//   3. partition it in SearchIndex.build.
//
// LANGUAGE MODEL (read SearchVernacular.kt for the full story):
//   Content is Latin (`lat`, constant) + ONE user-selected vernacular shown at
//   a time, but the INDEX collects Latin + EVERY available vernacular field so
//   search works for any current/future selection. Extractors NEVER hardcode
//   `eng` as the only vernacular: structured fragments are flattened via
//   `translatable(lat, vernaculars)` (lat + each vernacular in
//   `SearchVernacular.keys`); prose-only English fields are collected through
//   `vernacularProse(...)` which is likewise keyed off `SearchVernacular.keys`.
//   Adding a language is a one-line edit in SearchVernacular.keys plus teaching
//   each model's vernacular map below — no extractor-body edits.

object SearchExtractors {

    // ---- Generic translation-text collector ----

    /**
     * Concatenates an arbitrary list of nullable translation/text fields into
     * one whitespace-joined blob, dropping nulls/empties. The single choke
     * point that flattens `lat` + every vernacular field into one folded blob.
     */
    fun collectText(fields: List<String?>): String =
        fields
            .filterNotNull()
            .map { it.strippingEm }
            .filter { it.isNotBlank() }
            .joinToString(" ")

    /** Convenience vararg overload (Latin-only or already-flat field groups). */
    fun collectText(vararg fields: String?): String = collectText(fields.toList())

    // ---- Translatable flattening (mirror of iOS `Translatable.translatableFields`) ----
    //
    // Kotlin can't retroactively make the model data classes implement an
    // interface, so instead of `fragment.translatableFields` we flatten a
    // (latText, vernaculars-map) pair here. Iterating `SearchVernacular.keys`
    // (not the map) keeps order stable and auto-includes future languages.

    private fun translatable(latText: String?, vernaculars: Map<String, String?>): List<String?> {
        val out = mutableListOf<String?>(latText)
        for (key in SearchVernacular.keys) {
            if (vernaculars.containsKey(key)) out.add(vernaculars[key])
        }
        return out
    }

    /**
     * Collects a per-language prose field that is NOT part of a structured
     * fragment — e.g. a Saint identity quote or a Reference summary that today
     * exists only in English. Caller supplies a lambda mapping a vernacular key
     * to that language's value; we iterate `SearchVernacular.keys` so an added
     * `es`/`fr` prose field is picked up by the same call.
     */
    private fun vernacularProse(value: (String) -> String?): List<String?> =
        SearchVernacular.keys.map { value(it) }

    // ---- Per-model translatable adapters ----
    // The ONLY place a vernacular field name ("eng") appears. Add `es`/`fr`
    // entries here (and to SearchVernacular.keys) when those languages land;
    // nothing in the extractor bodies below changes.

    private fun fields(t: ProperText?): List<String?> =
        if (t == null) emptyList() else translatable(t.lat, mapOf("eng" to t.eng))

    private fun fields(r: ProperReading?): List<String?> =
        if (r == null) emptyList() else translatable(r.lat, mapOf("eng" to r.eng))

    private fun fields(l: Prayer.Line): List<String?> =
        translatable(l.lat, mapOf("eng" to l.eng))

    private fun fields(l: MissalSection.Line): List<String?> =
        translatable(l.lat, mapOf("eng" to l.eng))

    private fun fields(v: Hour.Part.Verse): List<String?> =
        translatable(v.lat, mapOf("eng" to v.eng))

    private fun fields(s: ReferenceEntry.Scripture?): List<String?> =
        if (s == null) emptyList() else translatable(s.lat, mapOf("eng" to s.eng))

    private fun fields(sec: Saint.Section): List<String?> =
        translatable(sec.lat, mapOf("eng" to sec.eng))

    /** Hour.Part carries many parallel lat/eng pairs; expose them all at once. */
    private fun fields(part: Hour.Part): List<String?> = translatable(
        latText = collectText(
            part.lat, part.latR, part.v1Lat, part.r1Lat, part.v2Lat, part.r2Lat, part.antiphonLat
        ),
        vernaculars = mapOf(
            "eng" to collectText(
                part.eng, part.engR, part.v1Eng, part.r1Eng, part.v2Eng, part.r2Eng,
                part.engBody, part.antiphonEng
            )
        ),
    )

    // ---- Prose-only vernacular accessors (English-only today) ----

    private fun prayerVernacular(p: Prayer, key: String): String? =
        if (key == "eng") p.eng else null

    private fun missalVernacular(s: MissalSection, key: String): String? =
        if (key == "eng") s.english else null

    private fun properVernacular(mp: MassProper, key: String): String? =
        if (key == "eng") mp.english else null

    private fun referenceProse(e: ReferenceEntry, key: String): String? =
        if (key == "eng") collectText(e.summary, e.history, e.practice, e.notes) else null

    private fun saintProse(s: Saint, key: String): String? =
        if (key == "eng") collectText(s.quote, s.penance) else null

    private fun saintPrayerVernacular(pr: Saint.SaintPrayer, key: String): String? =
        if (key == "eng") pr.eng else null

    /** Builds the canonical document id string. */
    private fun docId(type: ContentType, contentId: String, position: String? = null): String =
        if (position != null) "${type.wire}:$contentId#$position" else "${type.wire}:$contentId"

    // ---- Prayer → 1 doc per prayer ----

    fun prayers(items: List<Prayer>): List<SearchDocument> = items.map { p ->
        val f = mutableListOf<String?>(p.title, p.note)
        f += vernacularProse { prayerVernacular(p, it) }   // prayer-level body
        for (line in p.lines) f += fields(line)
        // Snippet uses the currently-shipping vernacular (eng) for display.
        val display = collectText(listOf(p.eng) + p.lines.map { it.eng })
        SearchDocument(
            id = docId(ContentType.PRAYER, p.slug),
            type = ContentType.PRAYER,
            title = p.title,
            subtitle = p.category,
            displayText = display,
            searchText = SearchNormalizer.fold(collectText(f)),
            target = DeepLinkTarget(ContentType.PRAYER, p.slug, null),
        )
    }

    // ---- MissalSection (Ordinary) → 1 doc per section ----

    fun missalSections(items: List<MissalSection>): List<SearchDocument> = items.map { s ->
        val f = mutableListOf<String?>(s.title, s.label)
        f += vernacularProse { missalVernacular(s, it) }   // section heading text
        for (line in s.body) {
            f += fields(line)
            f.add(line.rubric)
        }
        val display = collectText(listOf(s.english) + s.body.map { it.eng })
        SearchDocument(
            id = docId(ContentType.MISSAL, s.slug),
            type = ContentType.MISSAL,
            title = s.title,
            subtitle = s.label ?: s.english,
            displayText = display,
            searchText = SearchNormalizer.fold(collectText(f)),
            target = DeepLinkTarget(ContentType.MISSAL, s.slug, null),
        )
    }

    // ---- MassProper → 1 doc per element + 1 "feast" title doc ----

    /**
     * The ordered list of named proper-element fragments on a MassProper. Each
     * fragment's `fields(...)` already covers lat + every vernacular. Adding a
     * proper element = add a row here.
     */
    private fun properElements(mp: MassProper): List<Pair<String, List<String?>>> = listOf(
        "introit" to fields(mp.introit),
        "collect" to fields(mp.collect),
        "epistle" to fields(mp.epistle),
        "gradual" to fields(mp.gradual),
        "alleluia" to fields(mp.alleluia),
        "tract" to fields(mp.tract),
        "sequence" to fields(mp.sequence),
        "gospel" to fields(mp.gospel),
        "offertory" to fields(mp.offertory),
        "secret" to fields(mp.secret),
        "communion" to fields(mp.communion),
        "postcommunion" to fields(mp.postcommunion),
    )

    fun propers(items: List<MassProper>): List<SearchDocument> {
        val docs = mutableListOf<SearchDocument>()
        for (mp in items) {
            // 1 title-only "feast" doc for calendar findability.
            val feastFields = mutableListOf<String?>(mp.title)
            feastFields += vernacularProse { properVernacular(mp, it) }
            val feastSearch = SearchNormalizer.fold(collectText(feastFields))
            if (feastSearch.isNotEmpty()) {
                docs.add(
                    SearchDocument(
                        id = docId(ContentType.MISSAL, mp.slug, "feast"),
                        type = ContentType.MISSAL,
                        title = mp.title,
                        subtitle = mp.english,
                        displayText = collectText(mp.english),
                        searchText = feastSearch,
                        target = DeepLinkTarget(ContentType.MISSAL, mp.slug, "feast"),
                    )
                )
            }
            // 1 doc per element that has text.
            for ((name, elementFields) in properElements(mp)) {
                val folded = SearchNormalizer.fold(collectText(elementFields))
                if (folded.isEmpty()) continue
                docs.add(
                    SearchDocument(
                        id = docId(ContentType.MISSAL, mp.slug, name),
                        type = ContentType.MISSAL,
                        title = mp.title,
                        subtitle = name,
                        displayText = collectText(elementFields),
                        searchText = folded,
                        target = DeepLinkTarget(ContentType.MISSAL, mp.slug, name),
                    )
                )
            }
        }
        return docs
    }

    // ---- Hour (template hours) → 1 doc per Part that has text ----

    private fun partFields(part: Hour.Part): List<String?> {
        val f = mutableListOf<String?>(part.label, part.title)
        f += fields(part)
        part.verses?.forEach { v -> f += fields(v) }
        return f
    }

    fun hours(items: List<Hour>): List<SearchDocument> {
        val docs = mutableListOf<SearchDocument>()
        for (hour in items) {
            hour.parts.forEachIndexed { i, part ->
                val f = partFields(part)
                val folded = SearchNormalizer.fold(collectText(f))
                if (folded.isEmpty()) return@forEachIndexed
                val partTitle = part.title ?: part.label ?: hour.eng
                docs.add(
                    SearchDocument(
                        id = docId(ContentType.OFFICE, hour.slug, "part:$i"),
                        type = ContentType.OFFICE,
                        title = hour.eng,
                        subtitle = partTitle,
                        displayText = collectText(f),
                        searchText = folded,
                        target = DeepLinkTarget(ContentType.OFFICE, hour.slug, "part:$i"),
                    )
                )
            }
        }
        return docs
    }

    // ---- ReferenceEntry → reference (1/entry) or calendar (1/season) ----

    private const val CALENDAR_CATEGORY = "Calendarium"

    fun reference(items: List<ReferenceEntry>): List<SearchDocument> =
        items.filter { it.cat != CALENDAR_CATEGORY }.map { e ->
            val f = mutableListOf<String?>(e.title, e.latin)
            f += vernacularProse { referenceProse(e, it) }
            f += fields(e.scripture)
            SearchDocument(
                id = docId(ContentType.REFERENCE, e.slug),
                type = ContentType.REFERENCE,
                title = e.title,
                subtitle = e.cat,
                displayText = collectText(e.summary),
                searchText = SearchNormalizer.fold(collectText(f)),
                target = DeepLinkTarget(ContentType.REFERENCE, e.slug, null),
            )
        }

    fun calendar(items: List<ReferenceEntry>): List<SearchDocument> =
        items.filter { it.cat == CALENDAR_CATEGORY }.map { e ->
            val f = mutableListOf<String?>(e.title, e.latin)
            f += vernacularProse { referenceProse(e, it) }
            SearchDocument(
                id = docId(ContentType.CALENDAR, e.slug),
                type = ContentType.CALENDAR,
                title = e.title,
                subtitle = e.latin ?: e.cat,
                displayText = collectText(e.summary),
                searchText = SearchNormalizer.fold(collectText(f)),
                target = DeepLinkTarget(ContentType.CALENDAR, e.slug, null),
            )
        }

    // ---- Saint → 1 identity + 1 per section + 1 per prayer ----

    fun saints(items: List<Saint>): List<SearchDocument> {
        val docs = mutableListOf<SearchDocument>()
        for (s in items) {
            // Identity doc. Name is language-neutral; quote/penance are prose.
            val idFields = mutableListOf<String?>(s.name, s.title, s.penanceLatin)
            idFields += vernacularProse { saintProse(s, it) }
            docs.add(
                SearchDocument(
                    id = docId(ContentType.SAINT, s.slug),
                    type = ContentType.SAINT,
                    title = s.name,
                    subtitle = s.title,
                    displayText = collectText(s.quote),
                    searchText = SearchNormalizer.fold(collectText(idFields)),
                    target = DeepLinkTarget(ContentType.SAINT, s.slug, null),
                )
            )
            // Section docs.
            s.sections.forEachIndexed { i, section ->
                val f = fields(section).toMutableList()
                for (pr in section.practices) { f.add(pr.t); f.add(pr.d) }
                val folded = SearchNormalizer.fold(collectText(f))
                if (folded.isEmpty()) return@forEachIndexed
                docs.add(
                    SearchDocument(
                        id = docId(ContentType.SAINT, s.slug, "section:$i"),
                        type = ContentType.SAINT,
                        title = s.name,
                        subtitle = s.title,
                        displayText = collectText(section.eng),
                        searchText = folded,
                        target = DeepLinkTarget(ContentType.SAINT, s.slug, "section:$i"),
                    )
                )
            }
            // Prayer docs.
            (s.prayers ?: emptyList()).forEachIndexed { i, pr ->
                val f = mutableListOf<String?>(pr.title, pr.latin, pr.note)
                f += vernacularProse { saintPrayerVernacular(pr, it) }
                val folded = SearchNormalizer.fold(collectText(f))
                if (folded.isEmpty()) return@forEachIndexed
                docs.add(
                    SearchDocument(
                        id = docId(ContentType.SAINT, s.slug, "prayer:$i"),
                        type = ContentType.SAINT,
                        title = pr.title,
                        subtitle = s.name,
                        displayText = collectText(pr.eng),
                        searchText = folded,
                        target = DeepLinkTarget(ContentType.SAINT, s.slug, "prayer:$i"),
                    )
                )
            }
        }
        return docs
    }
}
