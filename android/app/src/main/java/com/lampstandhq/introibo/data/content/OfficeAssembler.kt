package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.LiturgicalSeason
import com.lampstandhq.introibo.data.liturgical.MarianAntiphon
import com.lampstandhq.introibo.data.liturgical.isEmberDay
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData
import com.lampstandhq.introibo.storage.settings.MissalRite

/**
 * Assembles a canonical-hour template with day-specific psalter overrides,
 * seasonal hymn overrides, and the current Marian antiphon.
 *
 * Direct port of Introibo/Data/OfficeAssembler.swift.
 */
class OfficeAssembler(
    private val weeklyPsalter: Map<String, Map<String, Hour.Part>>,
    private val seasonalHymns: Map<String, Map<String, Hour.Part>>,
    internal val temporalPropers: Map<String, Map<String, Hour.Part>> = emptyMap(),
    private val marianAntiphons: List<MarianAntiphonData>,
    private val psalter: Map<String, Map<String, List<String>>> = emptyMap(),
) {
    // On feasts (Semiduplex and above, rank >= 2.0), Lauds and Vespers use
    // the festal psalm scheme baked into the hour template rather than the
    // weekday ferial set from psalter_weekly.
    private val festalPsalmKeys = setOf(
        "laudes.psalm1", "laudes.psalm2", "laudes.psalm3",
        "laudes.canticle1", "laudes.psalm4",
        "vesperae.psalm1", "vesperae.psalm2", "vesperae.psalm3",
        "vesperae.psalm4", "vesperae.psalm5",
    )

    // Compline uses the Sunday psalms (Ps 4, 90, 133) only on Sundays and
    // feasts of I and II class (rank >= 5); ferias, Simples, and III-class
    // feasts use the day-of-the-week ferial Compline.
    private val festalComplineKeys = setOf(
        "completorium.antiphon",
        "completorium.psalm1", "completorium.psalm2", "completorium.psalm3",
    )

    // The Little Hours (Terce, Sext, None) take the Sunday psalms (portions
    // of Ps 118) only on Sundays and feasts of I class (rank >= 6); all else
    // uses the day-of-the-week ferial psalms. Higher threshold than Compline.
    private val festalLittleHourKeys = setOf(
        "ant_tertia", "tertia.psalm1", "tertia.psalm2", "tertia.psalm3",
        "ant_sexta", "sexta.psalm1", "sexta.psalm2", "sexta.psalm3",
        "ant_nona", "nona.psalm1", "nona.psalm2", "nona.psalm3",
    )

    // Day-hours whose standalone pre-Collect Pater Noster is only said as part
    // of the Preces (stripped when Preces are omitted). Matins and the Office
    // of the Dead are deliberately excluded.
    private val precesHours = setOf(
        "laudes", "vesperae", "prima", "tertia", "sexta", "nona", "completorium",
    )

    fun assemble(template: Hour, context: LiturgicalContext, isFestal: Boolean = false, festalCompline: Boolean = false, festalLittleHours: Boolean = false, matinsNocturns: Int = 3, matinsTeDeum: Boolean = true, rite: MissalRite = MissalRite.RITE_1962, fallbackCollect: Hour.Part? = null): Hour {
        var dayKey = dayKeys[context.dayOfWeek]
        val seasonKey = seasonString(context.season)

        // Easter/Pentecost octave: use Sunday psalms for all hours
        val isOctave = isEasterOrPentecostOctave(context)
        if (isOctave && context.dayOfWeek != 0) {
            dayKey = "sunday"
        }

        val dayOverrides = weeklyPsalter[dayKey] ?: emptyMap()
        val seasonOverrides = seasonalHymns[seasonKey] ?: emptyMap()
        val rawTemporalOverrides = context.temporalKey?.let { temporalPropers[it] } ?: emptyMap()
        val temporalOverrides =
            remapProperOverrides(rawTemporalOverrides, template.slug).toMutableMap()

        // Day-collect resolution. The collect of the day belongs to Matins,
        // Lauds, the Little Hours, and Vespers (Prime's and Compline's
        // collects are invariable and keyed separately). Per-annum ferias
        // repeat the preceding Sunday's collect; Lent/Passiontide ferias
        // carry their own as DO's "oratio_2", and at Vespers a DISTINCT
        // proper collect as "oratio_3". A sanctoral winner's own collect is
        // layered on top later in hourForToday and wins.
        if (template.slug in COLLECT_HOURS && "oratio" !in temporalOverrides) {
            val candidates = mutableListOf<Hour.Part?>()
            if (template.slug == "vesperae") candidates.add(rawTemporalOverrides["oratio_3"])
            candidates.add(rawTemporalOverrides["oratio"])
            candidates.add(rawTemporalOverrides["oratio_2"])
            val tKey = context.temporalKey
            val sundayKey = tKey?.let { precedingSundayKey(it) }
            val sunday = sundayKey?.let { temporalPropers[it] }
            if (sunday != null) {
                candidates.add(sunday["oratio"])
                candidates.add(sunday["oratio_2"])
            }
            // Last resort: the day's MASS collect, resolved by the caller via
            // the Missal pipeline (which already handles resumed Sundays,
            // stub redirects, and the early-January ferias). The office and
            // Mass collect of the day coincide.
            candidates.add(fallbackCollect)
            candidates.filterNotNull().firstOrNull()?.let {
                temporalOverrides["oratio"] = rekeyed(it, "oratio")
            }
        }

        val assembledParts = template.parts.map { part ->
            val key = part.variationKey ?: return@map part

            if (part.type == "marian") {
                return@map marianPart(context.marian, fallback = part)
            }

            // Temporal propers (highest priority for non-psalm parts)
            temporalOverrides[key]?.let { return@map rekeyed(it, key) }

            // Ferial weekday hymns (per annum): the psalter's own Mon-Sat
            // hymn cycle beats the season's default (which is the SUNDAY
            // hymn) on non-festal weekdays. Seasonal hymns still win in
            // every proper season (Advent, Lent, Paschaltide, ...).
            if (part.type == "hymn" && seasonKey == "ordinary" && !isFestal) {
                dayOverrides[key]?.let { return@map rekeyed(it, key) }
            }

            // Seasonal overrides: hymns change every season. Seasonal antiphons
            // apply on ferias (feasts keep the commune/proper antiphon), EXCEPT
            // in Paschaltide where the "Alleluia" antiphon is used universally.
            val isSeasonalAntiphon = part.type == "antiphon" || part.type == "canticle"
            val antiphonSeasonApplies = !isFestal ||
                context.season == LiturgicalSeason.EASTER ||
                context.season == LiturgicalSeason.PENTECOST
            if (part.type == "hymn" || (isSeasonalAntiphon && antiphonSeasonApplies)) {
                seasonOverrides[key]?.let { override ->
                    // Antiphon-only override on a canticle: merge the antiphon
                    // without replacing the canticle's verses.
                    if (override.antiphonLat != null && override.verses == null && part.verses != null) {
                        return@map part.copy(
                            antiphonLat = override.antiphonLat,
                            antiphonEng = override.antiphonEng,
                        )
                    }
                    return@map rekeyed(override, key)
                }
            }

            // On festal days, keep the template's festal psalms for Lauds
            // and Vespers (the weekday psalter would replace them with ferial).
            if (isFestal && key in festalPsalmKeys) {
                return@map part
            }

            // On Sundays and I/II-class feasts, keep the festal Compline
            // (Sunday psalms + "Miserere" antiphon) instead of the ferial set.
            if (festalCompline && key in festalComplineKeys) {
                return@map part
            }

            // On Sundays and I-class feasts, keep the festal Little Hours
            // (Ps 118 portions) instead of the day-of-the-week ferial psalms.
            if (festalLittleHours && key in festalLittleHourKeys) {
                return@map part
            }

            dayOverrides[key]?.let {
                // The ferial hymn/canticle-antiphon/versicle cycle belongs to
                // the ferial office only -- festal days keep the template's
                // (Sunday) defaults until the proper/commune layers land.
                if (isFestal && key in FERIAL_ONLY_DAY_KEYS) {
                    return@map part
                }
                return@map rekeyed(it, key)
            }

            part
        }

        // Inline psalm text from psalter.json for any psalm part that has
        // a ref but no verses (or empty verses).
        val psalmInlined = assembledParts.map { inlinePsalmText(it) }

        // Apply temporal per-psalm antiphon overrides. Uses the same mapping
        // as ContentStore.applyProperOverrides (incl. the Matins offset --
        // matutinum.psalm1 is the invariable Venite).
        val antiphonApplied = psalmInlined.map { part ->
            val key = part.variationKey ?: return@map part
            val antKey = PSALM_TO_ANTIPHON_KEY[key] ?: return@map part
            val antOverride = temporalOverrides[antKey] ?: return@map part
            part.copy(antiphonLat = antOverride.lat, antiphonEng = antOverride.eng)
        }

        // Septuagesima through Holy Saturday: replace trailing "Alleluja" in
        // the "Deus in adjutorium" response with "Laus tibi, Domine, Rex
        // aeternae gloriae." (1962 Breviarium Romanum rubric). Must NOT fire
        // during Paschal time.
        val lausTibiApplied = if (shouldSubstituteLausTibi(context)) {
            antiphonApplied.map { part ->
                if (part.type != "vr") return@map part
                val latR = part.latR ?: return@map part
                if (!latR.contains("Allelúja")) return@map part
                part.copy(
                    latR = latR
                        .replace("Allelúja.", "Laus tibi, Dómine, Rex ætérnæ glóriæ.")
                        .replace("Allelúja", "Laus tibi, Dómine, Rex ætérnæ glóriæ"),
                    engR = part.engR
                        ?.replace("Alleluia.", "Praise be to Thee, O Lord, King of eternal glory.")
                        ?.replace("Alleluia", "Praise be to Thee, O Lord, King of eternal glory"),
                )
            }
        } else {
            antiphonApplied
        }

        // Septuagesima through Holy Saturday: strip "Alleluia" from antiphons.
        // The per-annum Little Hours antiphons embed alleluias; during this
        // penitential window they are removed, leaving the bare antiphon text.
        val alleluiaStripped = if (shouldSubstituteLausTibi(context)) {
            lausTibiApplied.map { part ->
                if (part.type != "antiphon") return@map part
                part.copy(
                    lat = part.lat?.let { stripAlleluia(it) },
                    eng = part.eng?.let { stripAlleluia(it) },
                )
            }
        } else {
            lausTibiApplied
        }

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        val filteredParts = if (template.slug == "matutinum") {
            // Tenebrae: Matins of Holy Thursday, Good Friday, Holy Saturday.
            val isTenebrae = context.temporalKey in setOf("quad6-4", "quad6-5", "quad6-6")
            filterMatinsParts(alleluiaStripped, matinsNocturns, matinsTeDeum, isTenebrae)
        } else if (template.slug == "prima") {
            // Festal Prime (Sunday/I-class feast or Easter/Pentecost octave):
            // 4 psalms (Ps 53, 117, 118 I, 118 II). Ferial Prime: 3 psalms.
            // During octave, drop Ps 117 instead.
            if (isOctave && context.dayOfWeek != 0) {
                alleluiaStripped.filter { it.variationKey != "prima.psalm2" }
            } else if (!festalLittleHours) {
                alleluiaStripped.filter { it.variationKey != "prima.psalm4" }
            } else {
                alleluiaStripped
            }
        } else {
            alleluiaStripped
        }

        // Preces Feriales. The standalone Pater before the collect is not
        // said at the day hours under the 1960 rubrics; when the Preces fire
        // they carry their own Pater. (The opening "Pater, Ave" is kept.)
        var precesApplied = filteredParts
        if (template.slug in precesHours) {
            precesApplied = precesApplied.filter { part ->
                !(part.type == "pater" && part.variationKey.isNullOrEmpty()
                    && !(part.label ?: "").contains("Ave"))
            }
            if (shouldIncludePreces(context, rite, template.slug)) {
                precesApplied = insertPreces(precesApplied, template.slug)
            }
        }

        // Suppress Gloria Patri at the end of psalms during Passiontide
        // and in the Office of the Dead.
        val finalParts = if (shouldOmitGloriaPatri(context, template.slug)) {
            precesApplied.map { stripGloriaPatriFromPsalm(it) }
        } else {
            precesApplied
        }

        return Hour(
            slug = template.slug,
            name = template.name,
            eng = template.eng,
            time = template.time,
            hour = template.hour,
            minute = template.minute,
            glyph = template.glyph,
            order = template.order,
            intro = template.intro,
            parts = finalParts,
        )
    }

    // ---- Matins: 1-Nocturn vs 3-Nocturn filtering (Item 1 & Item 4) ----
    //
    // 1962 Breviary rules:
    //   3 Nocturns (9 psalms, 9 readings, Te Deum): Sundays, feasts rank 1-3
    //   1 Nocturn  (3 psalms, 3 readings, NO Te Deum): Ferial days (weekdays without a feast)
    //
    // Simplified logic (no full feast-rank system yet):
    //   Sunday (dayOfWeek == 0): always 3 nocturns
    //   Weekday (dayOfWeek 1-6): 1 nocturn (keep only Nocturn I material)
    //
    // Te Deum is also omitted on Sundays during:
    //   - Septuagesima, Sexagesima, Quinquagesima (pre-Lent Sundays)
    //   - Sundays in Lent
    //   - Passion Sunday and Palm Sunday
    //
    // Matins structure (1960/1962 rubrics). Every Matins has 9 psalms; the
    // split is 3 nocturns / 9 lessons / Te Deum for I- and II-class feasts only,
    // and 1 nocturn / 9 psalms / 3 lessons for everything else (all Sundays,
    // III-class feasts, ferias, octave days). The nocturn count and Te Deum
    // decision are computed in ContentStore and passed in.
    private fun filterMatinsParts(parts: List<Hour.Part>, nocturns: Int, includeTeDeum: Boolean, isTenebrae: Boolean = false): List<Hour.Part> {
        val structured = if (nocturns >= 3) {
            if (includeTeDeum) parts else parts.filter { !isTeDeum(it) }
        } else {
            buildOneNocturn(parts, includeTeDeum)
        }
        return if (isTenebrae) applyTenebrae(structured) else structured
    }

    /**
     * Tenebrae (Matins of the Sacred Triduum) omits the Incipit, Invitatory,
     * hymn, Te Deum, and Conclusion: it begins directly with the antiphon of
     * the first psalm and ends after the collect.
     */
    private fun applyTenebrae(parts: List<Hour.Part>): List<Hour.Part> {
        var result = parts
        val firstHeading = result.indexOfFirst {
            it.type == "heading" && (it.label ?: "").contains("Noct")
        }
        if (firstHeading != -1) {
            result = result.subList(firstHeading, result.size)
        }
        return result.filter { it.type != "closing" && !isTeDeum(it) }
    }

    /**
     * Build a 1-nocturn Matins: all 9 psalms (pulled from the three template
     * nocturns into a single nocturn), the first versicle, the three lessons
     * and responsories of Nocturn I, an optional Te Deum, then the closing.
     */
    private fun buildOneNocturn(parts: List<Hour.Part>, includeTeDeum: Boolean): List<Hour.Part> {
        val headingIdxs = parts.indices.filter {
            parts[it].type == "heading" && (parts[it].label ?: "").contains("Noct")
        }
        val firstHeading = headingIdxs.firstOrNull() ?: return parts

        // Everything before the first nocturn heading: invitatory + hymn.
        val result = parts.subList(0, firstHeading).toMutableList()

        // From each nocturn, take the antiphon + psalms (the run between the
        // heading and that nocturn's versicle), dropping the nocturn heading.
        for (h in headingIdxs) {
            var i = h + 1
            while (i < parts.size && parts[i].type != "vr") {
                result.add(parts[i])
                i++
            }
        }

        // The single versicle (the first nocturn's "nocturn_1_versum").
        val versicleIdx = parts.indexOfFirst { it.variationKey == "nocturn_1_versum" }
        if (versicleIdx != -1) {
            result.add(parts[versicleIdx])

            // Nocturn I's lesson block: from after that versicle up to the
            // second nocturn heading (Pater, absolution, blessings, the three
            // lessons + responsories).
            val secondHeading = if (headingIdxs.size > 1) headingIdxs[1] else parts.size
            if (versicleIdx + 1 < secondHeading) {
                result.addAll(parts.subList(versicleIdx + 1, secondHeading))
            }
        }

        // Te Deum (optional), then the closing material that follows it.
        val teDeumIdx = parts.indexOfFirst { isTeDeum(it) }
        if (teDeumIdx != -1) {
            if (includeTeDeum) result.add(parts[teDeumIdx])
            if (teDeumIdx + 1 < parts.size) {
                result.addAll(parts.subList(teDeumIdx + 1, parts.size))
            }
        }

        return result
    }

    private fun isTeDeum(part: Hour.Part): Boolean {
        return part.type == "canticle" && (part.label ?: "").contains("Te Deum")
    }

    // ---- Laus tibi substitution (Septuagesima-Holy Saturday) ----
    //
    // From First Vespers of Septuagesima Sunday through Holy Saturday, the
    // "Alleluia" at the end of the "Deus in adjutorium" versicle response is
    // replaced by "Laus tibi, Domine, Rex aeternae gloriae."

    private fun shouldSubstituteLausTibi(context: LiturgicalContext): Boolean {
        if (context.season == LiturgicalSeason.LENT || context.season == LiturgicalSeason.PASSION) {
            return true
        }
        // Pre-Lent (Septuagesima through Saturday before Ash Wednesday):
        // temporalKey is "quadp1-0" through "quadp3-6"
        val key = context.temporalKey
        if (key != null && key.startsWith("quadp")) {
            return true
        }
        return false
    }

    /**
     * Remove leading/trailing "Alleluia" words from an antiphon (Septuagesima
     * through Lent). E.g. "Allelúja, * deduc me, Dómine…, allelúja, allelúja."
     * -> "Deduc me, Dómine…". Leaves the text unchanged if stripping would
     * empty it (a purely-alleluiatic antiphon).
     */
    private fun stripAlleluia(text: String): String {
        // Latin "Allelúja" ends in -ja, English "Alleluia" in -ia.
        var s = text.replace(
            Regex("[,;]?\\s*[Aa]llel[úu][ji]a[,.]?(\\s*[Aa]llel[úu][ji]a[,.]?)*\\s*$"), "")
        s = s.replace(Regex("^[Aa]llel[úu][ji]a[,.]?\\s*\\*?\\s*"), "")
        s = s.trim()
        if (s.isEmpty()) return text
        return s.replaceFirstChar { it.uppercase() }
    }

    // ---- Gloria Patri suppression (Passiontide & Office of the Dead) ----
    //
    // In the 1962 Breviary the Gloria Patri doxology at the end of psalms
    // is omitted from Passion Sunday through Holy Saturday and throughout
    // the Office of the Dead.

    /**
     * Returns true when the Gloria Patri should be stripped from psalm endings.
     */
    private fun shouldOmitGloriaPatri(context: LiturgicalContext, hourSlug: String): Boolean {
        if (context.season == LiturgicalSeason.PASSION) {
            return true
        }
        if (hourSlug == "office-of-the-dead") {
            return true
        }
        return false
    }

    /**
     * If the part is a psalm or canticle whose ending contains the Gloria Patri
     * doxology, return a copy with those verses removed.
     *
     * The doxology may appear as:
     *   (a) A single final verse: "Gloria Patri, et Filio, et Spiritui Sancto. Sicut erat ..."
     *   (b) Two verses: "Gloria Patri ..." followed by "Sicut erat ..."
     */
    private fun stripGloriaPatriFromPsalm(part: Hour.Part): Hour.Part {
        if (part.type != "psalm" && part.type != "canticle") return part
        val verses = part.verses ?: return part
        if (verses.isEmpty()) return part

        val lastVerse = verses.last()

        // Case (a): single combined verse starting with "Gloria Patri"
        if (lastVerse.lat.startsWith("Glória Patri")) {
            return part.copy(verses = verses.dropLast(1))
        }

        // Case (b): "Sicut erat" is the last verse, "Gloria Patri" is second-to-last
        if (verses.size >= 2
            && lastVerse.lat.startsWith("Sicut erat")
            && verses[verses.size - 2].lat.startsWith("Glória Patri")) {
            return part.copy(verses = verses.dropLast(2))
        }

        return part
    }

    // ---- Preces Feriales (Lauds & Vespers) ----
    //
    // Rite-specific scope (the preces are said KNEELING, before the collect):
    //   1962:      at LAUDS only, on Wednesdays and Fridays of Advent, Lent
    //              and Passiontide, and on Ember days.
    //   1955:      at Lauds AND Vespers on those same days (Cum nostra kept
    //              the ferial preces at both hours).
    //   pre-1955:  at Lauds and Vespers on all ferias of Advent, Lent and
    //              Passiontide, and on Ember days.
    // Never on Sundays or on feasts.

    /**
     * Determines whether Preces Feriales should be included in the Hour.
     */
    private fun shouldIncludePreces(context: LiturgicalContext, rite: MissalRite, hourSlug: String): Boolean {
        // Never on Sundays
        if (context.dayOfWeek == 0) return false

        // Not on high-rank weekday feasts (equivalent to Double rank or higher)
        val slug = context.properSlug
        if (slug != null && slug in HIGH_RANK_WEEKDAY_FEASTS) {
            return false
        }

        val penitential = context.season == LiturgicalSeason.ADVENT ||
            context.season == LiturgicalSeason.LENT ||
            context.season == LiturgicalSeason.PASSION
        val wedOrFri = context.dayOfWeek == 3 || context.dayOfWeek == 5

        return when (rite) {
            MissalRite.RITE_1962 -> hourSlug == "laudes" &&
                (context.isEmberDay || (penitential && wedOrFri))
            MissalRite.RITE_1955 -> (hourSlug == "laudes" || hourSlug == "vesperae") &&
                (context.isEmberDay || (penitential && wedOrFri))
            MissalRite.PRE_1955 -> (hourSlug == "laudes" || hourSlug == "vesperae") &&
                (penitential || context.isEmberDay)
        }
    }

    /**
     * Inserts the Preces Feriales parts into the assembled hour, placed
     * BEFORE the Collect (they are said kneeling, and conclude with the
     * "Domine, exaudi" that introduces the collect).
     */
    private fun insertPreces(parts: List<Hour.Part>, hour: String): List<Hour.Part> {
        val collectIndex = parts.indexOfFirst { it.type == "collect" }
        if (collectIndex == -1) return parts

        val precesParts = makePrecesParts(hour)

        return parts.subList(0, collectIndex) + precesParts + parts.subList(collectIndex, parts.size)
    }

    /**
     * Builds the Preces Feriales parts for the given hour (Lauds or Vespers).
     * Vespers uses Psalm 50 (Miserere) instead of Psalm 129 (De profundis).
     */
    private fun makePrecesParts(hour: String): List<Hour.Part> {
        val parts = mutableListOf<Hour.Part>()

        // Heading
        parts.add(Hour.Part(type = "heading", label = "Preces Feriales"))

        // Kyrie
        parts.add(
            Hour.Part(
                type = "preces",
                label = "Kyrie",
                lat = "Kýrie, eléison. Christe, eléison. Kýrie, eléison.",
                eng = "Lord, have mercy. Christ, have mercy. Lord, have mercy.",
            )
        )

        // Pater noster (said silently through "et ne nos inducas in tentationem")
        parts.add(
            Hour.Part(
                type = "preces",
                label = "Pater Noster",
                lat = "Pater noster, qui es in cælis, sanctificétur nomen tuum. Advéniat regnum tuum. Fiat volúntas tua, sicut in cælo et in terra. Panem nostrum quotidiánum da nobis hódie, et dimítte nobis débita nostra, sicut et nos dimíttimus debitóribus nostris.\n℣. Et ne nos indúcas in tentatiónem.\n℟. Sed líbera nos a malo.",
                eng = "Our Father, who art in heaven, hallowed be Thy name. Thy kingdom come. Thy will be done on earth, as it is in heaven. Give us this day our daily bread, and forgive us our trespasses, as we forgive those who trespass against us.\n℣. And lead us not into temptation.\n℟. But deliver us from evil.",
            )
        )

        // Intercession versicles
        parts.add(
            Hour.Part(
                type = "preces",
                label = "Versicles",
                verses = PRECES_VERSICLES,
            )
        )

        // Psalm -- De profundis (129) at Lauds, Miserere (50) at Vespers
        if (hour == "laudes") {
            parts.add(
                Hour.Part(
                    type = "preces",
                    label = "Psalmus 129; De profúndis",
                    lat = "De profúndis clamávi ad te, Dómine: * Dómine, exáudi vocem meam.\nFiant aures tuæ intendéntes * in vocem deprecatiónis meæ.\nSi iniquitátes observáveris, Dómine: * Dómine, quis sustinébit?\nQuia apud te propitiátio est: * et propter legem tuam sustínui te, Dómine.\nSustínuit ánima mea in verbo ejus: * sperávit ánima mea in Dómino.\nA custódia matutína usque ad noctem, * speret Israël in Dómino.\nQuia apud Dóminum misericórdia, * et copiósa apud eum redémptio.\nEt ipse rédimet Israël * ex ómnibus iniquitátibus ejus.\nGlória Patri, et Fílio, * et Spirítui Sancto.\nSicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.",
                    eng = "Out of the depths I have cried to Thee, O Lord: * Lord, hear my voice.\nLet Thine ears be attentive * to the voice of my supplication.\nIf Thou, O Lord, wilt mark iniquities: * Lord, who shall stand it?\nFor with Thee there is merciful forgiveness: * and by reason of Thy law I have waited for Thee, O Lord.\nMy soul hath relied on His word: * my soul hath hoped in the Lord.\nFrom the morning watch even until night, * let Israel hope in the Lord.\nBecause with the Lord there is mercy, * and with Him plentiful redemption.\nAnd He shall redeem Israel * from all his iniquities.\nGlory be to the Father, and to the Son, * and to the Holy Ghost.\nAs it was in the beginning, is now, and ever shall be, * world without end. Amen.",
                )
            )
        } else {
            parts.add(
                Hour.Part(
                    type = "preces",
                    label = "Psalmus 50; Miserére",
                    lat = "Miserére mei, Deus, * secúndum magnam misericórdiam tuam.\nEt secúndum multitúdinem miseratiónum tuárum, * dele iniquitátem meam.\nAmplius lava me ab iniquitáte mea, * et a peccáto meo munda me.\nQuóniam iniquitátem meam ego cognósco, * et peccátum meum contra me est semper.\nTibi soli peccávi, et malum coram te feci: * ut justificéris in sermónibus tuis, et vincas cum judicáris.\nEcce enim in iniquitátibus concéptus sum, * et in peccátis concépit me mater mea.\nEcce enim veritátem dilexísti: * incérta et occúlta sapiéntiæ tuæ manifestásti mihi.\nAspérges me hyssópo, et mundábor: * lavábis me, et super nivem dealbábor.\nAudítui meo dabis gáudium et lætítiam, * et exsultábunt ossa humiliáta.\nAvérte fáciem tuam a peccátis meis, * et omnes iniquitátes meas dele.\nCor mundum crea in me, Deus, * et spíritum rectum ínnova in viscéribus meis.\nNe projícias me a fácie tua, * et Spíritum Sanctum tuum ne áuferas a me.\nRedde mihi lætítiam salutáris tui, * et spíritu principáli confírma me.\nDocébo iníquos vias tuas, * et ímpii ad te converténtur.\nLíbera me de sanguínibus, Deus, Deus salútis meæ, * et exsultábit lingua mea justítiam tuam.\nDómine, lábia mea apéries, * et os meum annuntiábit laudem tuam.\nQuóniam si voluísses sacrifícium, dedíssem útique: * holocáustis non delectáberis.\nSacrificium Deo spíritus contribulátus: * cor contrítum et humiliátum, Deus, non despícies.\nBenígne fac, Dómine, in bona voluntáte tua Sion, * ut ædificéntur muri Jerúsalem.\nTunc acceptábis sacrifícium justítiæ, oblatiónes et holocáusta: * tunc impónent super altáre tuum vítulos.\nGlória Patri, et Fílio, * et Spirítui Sancto.\nSicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.",
                    eng = "Have mercy on me, O God, * according to Thy great mercy.\nAnd according to the multitude of Thy tender mercies, * blot out my iniquity.\nWash me yet more from my iniquity, * and cleanse me from my sin.\nFor I know my iniquity, * and my sin is always before me.\nTo Thee only have I sinned, and have done evil before Thee: * that Thou mayest be justified in Thy words, and mayest overcome when Thou art judged.\nFor behold I was conceived in iniquities, * and in sins did my mother conceive me.\nFor behold Thou hast loved truth: * the uncertain and hidden things of Thy wisdom Thou hast made manifest to me.\nThou shalt sprinkle me with hyssop, and I shall be cleansed: * Thou shalt wash me, and I shall be made whiter than snow.\nTo my hearing Thou shalt give joy and gladness, * and the bones that have been humbled shall rejoice.\nTurn away Thy face from my sins, * and blot out all my iniquities.\nCreate a clean heart in me, O God, * and renew a right spirit within my bowels.\nCast me not away from Thy face, * and take not Thy Holy Spirit from me.\nRestore unto me the joy of Thy salvation, * and strengthen me with a perfect spirit.\nI will teach the unjust Thy ways, * and the wicked shall be converted to Thee.\nDeliver me from blood, O God, Thou God of my salvation, * and my tongue shall extol Thy justice.\nO Lord, Thou wilt open my lips, * and my mouth shall declare Thy praise.\nFor if Thou hadst desired sacrifice, I would indeed have given it: * with burnt offerings Thou wilt not be delighted.\nA sacrifice to God is an afflicted spirit: * a contrite and humbled heart, O God, Thou wilt not despise.\nDeal favorably, O Lord, in Thy good will with Sion, * that the walls of Jerusalem may be built up.\nThen shalt Thou accept the sacrifice of justice, oblations and whole burnt offerings: * then shall they lay calves upon Thine altar.\nGlory be to the Father, and to the Son, * and to the Holy Ghost.\nAs it was in the beginning, is now, and ever shall be, * world without end. Amen.",
                )
            )
        }

        // Concluding versicles
        parts.add(
            Hour.Part(
                type = "preces",
                label = "Concluding Versicles",
                verses = CONCLUDING_VERSICLES,
            )
        )

        return parts
    }

    private fun seasonString(season: LiturgicalSeason): String = when (season) {
        LiturgicalSeason.ADVENT -> "advent"
        LiturgicalSeason.LENT -> "lent"
        LiturgicalSeason.PASSION -> "passion"
        LiturgicalSeason.EASTER -> "easter"
        LiturgicalSeason.CHRISTMAS -> "christmas"
        LiturgicalSeason.PENTECOST -> "ordinary"
        LiturgicalSeason.PER_ANNUM -> "ordinary"
    }

    private fun marianPart(antiphon: MarianAntiphon, fallback: Hour.Part): Hour.Part {
        // During Triduum the Marian antiphon is suppressed entirely.
        if (antiphon.isSuppressed) {
            return Hour.Part(
                type = "suppressed",
                variationKey = "completorium.marian",
            )
        }
        val data = marianAntiphons.firstOrNull { it.slug == antiphon.key }
            ?: return fallback
        return Hour.Part(
            type = "marian",
            label = "Marian Antiphon; ${data.title}",
            title = data.title,
            lat = data.lat,
            eng = data.eng,
            season = data.season,
            engBody = data.engBody,
            variationKey = "completorium.marian",
        )
    }

    // ---- Psalm text inlining from psalter.json ----
    //
    // When a psalm part carries a `ref` like "Ps 109" but has no verses (or
    // empty verses), look up the text in the loaded psalter dictionary and
    // build a Verse list from it.

    /** If part is a psalm/canticle with a psalter-matching ref and no verse
     *  text, return a copy with verses inlined from the psalter. */
    private fun inlinePsalmText(part: Hour.Part): Hour.Part {
        if (part.type != "psalm" && part.type != "canticle") return part
        // Only inline when verses are missing or empty
        val existing = part.verses
        if (existing != null && existing.isNotEmpty()) return part
        val ref = part.ref ?: return part
        val key = psalterKey(ref) ?: return part
        val entry = psalter[key] ?: return part
        val latVerses = entry["lat"] ?: emptyList()
        val engVerses = entry["eng"] ?: emptyList()
        val count = maxOf(latVerses.size, engVerses.size)
        if (count == 0) return part
        val verses = (0 until count).map { i ->
            Hour.Part.Verse(
                lat = latVerses.getOrElse(i) { "" },
                eng = engVerses.getOrElse(i) { "" },
            )
        }
        return part.copy(verses = verses)
    }

    // ---- Easter/Pentecost Octave detection ----
    //
    // During the octaves of Easter (pasc0-*) and Pentecost (pasc7-*), all
    // days are I class. Rubric 172 requires Sunday psalms at all hours
    // (Lauds, Vespers, Little Hours) and the festal Prime set (Ps 53,
    // 118 pars I, 118 pars II -- omitting Ps 117).

    /** Returns true when the current day falls within the Easter or Pentecost octave. */
    private fun isEasterOrPentecostOctave(context: LiturgicalContext): Boolean {
        val key = context.temporalKey ?: return false
        return key.startsWith("pasc0-") || key.startsWith("pasc7-")
    }

    companion object {
        // ---- Temporal-propers key translation ----
        //
        // The hours.json variationKeys now use the same key format as the
        // DivinumOfficium import (e.g. "capitulum_laudes", "hymnus_vespera",
        // "ant_laudes").  This alias table handles variant spellings (e.g.
        // "hymnusm_*" metre variants -> canonical hymn key) and provides
        // backward compatibility with legacy dotted keys that may still
        // appear in psalter_weekly or hymns_seasonal.
        //
        // Direction: source key -> canonical variationKey in hours.json
        private val TEMPORAL_KEY_ALIASES: Map<String, String> = mapOf(
            // Lauds -- variant hymn spellings / rubric variants
            "hymnusm_laudes"           to "hymnus_laudes",
            "hymnus_laudes_"           to "hymnus_laudes",
            "ant_laudes_"              to "ant_laudes",
            "ant_laudesc"              to "ant_laudes",
            // Vespers -- variant hymn spellings / rubric variants
            // (ant_vespera_3 -- the 2nd-Vespers psalm-antiphon list -- is
            // handled semantically in remapProperOverrides, NOT aliased onto
            // the Magnificat-antiphon slot.)
            "hymnusm_vespera"          to "hymnus_vespera",
            "hymnus_vespera_3"         to "hymnus_vespera",
            // Vespers -- capitulum variants (sanctoral, e.g. Christmas)
            "capitulum_vespera_1"      to "vesperae.capitulum",
            "capitulum_vespera_3"      to "vesperae.capitulum",
            // Matins -- variant hymn spelling
            "hymnusm_matutinum"        to "hymnus_matutinum",
            "hymnus_matutinum_"        to "hymnus_matutinum",
            // Nocturn versum variants (trailing underscore = rubrical variant)
            "nocturn_2_versum_"        to "nocturn_2_versum",
            "nocturn_3_versum_"        to "nocturn_3_versum",
            // Versicle variant with trailing underscore
            "versum_1_"                to "versum_1",
            // Doxology rubric variant
            "doxology_"                to "doxology",
            // Vespers -- 2nd Vespers versicle falls back to versum_2 slot
            "versum_3"                 to "versum_2",
        )

        /** Build an expanded overrides dictionary that includes both the raw
         *  temporal-propers keys AND their translated hours.json equivalents. */
        private fun expandedOverrides(raw: Map<String, Hour.Part>): Map<String, Hour.Part> {
            val result = raw.toMutableMap()
            for ((tpKey, vk) in TEMPORAL_KEY_ALIASES) {
                raw[tpKey]?.let { if (vk !in result) result[vk] = it }
            }
            // Reverse: hours.json-style key -> DO key
            for ((tpKey, vk) in TEMPORAL_KEY_ALIASES) {
                raw[vk]?.let { if (tpKey !in result) result[tpKey] = it }
            }
            return result
        }

        // ---- Semantic key remapping (DivinumOfficium -> template slots) ----
        //
        // The DO import keeps DO's own section semantics, which COLLIDE with
        // the template's variationKeys:
        //   Ant 1/2/3      = 1st-Vespers Magnificat / Benedictus / 2nd-Vespers
        //                    Magnificat antiphons (canticle antiphons) -- but
        //                    the template's ant_1/2/3 are the MATINS NOCTURN
        //                    slots.
        //   Ant Matutinum  = the nocturn antiphons, as a newline list.
        //   Ant Vespera / Ant Laudes = the five PSALM antiphons as a newline
        //                    list (the curated communes already carry
        //                    single-line canticle antiphons instead).
        //   Versum 1/2/3   = 1st-Vespers / Lauds / 2nd-Vespers versicles --
        //                    but the template's versum_1 is the LAUDS slot and
        //                    versum_2 the VESPERS slot.
        // Mirror of OfficeAssembler.swift remapProperOverrides.

        private fun latLines(part: Hour.Part?): List<String> =
            part?.lat?.split("\n")?.filter { it.isNotEmpty() } ?: emptyList()

        private fun engLines(part: Hour.Part?): List<String> =
            part?.eng?.split("\n")?.filter { it.isNotEmpty() } ?: emptyList()

        private fun antiphonPart(lat: String, eng: String?, label: String, vk: String): Hour.Part =
            Hour.Part(type = "antiphon", label = label, lat = lat, eng = eng, variationKey = vk)

        private fun rekeyed(part: Hour.Part, vk: String): Hour.Part =
            part.copy(variationKey = vk)

        /** Distribute a multi-line antiphon list onto the per-psalm dotted
         *  keys, without clobbering explicit ones. */
        private fun setPsalmAntiphons(prefix: String, list: Hour.Part,
                                      o: MutableMap<String, Hour.Part>) {
            val lats = latLines(list)
            val engs = engLines(list)
            for ((i, lat) in lats.withIndex()) {
                if (i >= 9) break
                val key = "$prefix.antiphon.psalm${i + 1}"
                if (key in o) continue
                o[key] = antiphonPart(lat, engs.getOrNull(i), "Antiphon", key)
            }
        }

        /** Hour-aware semantic remap of a proper/commune/temporal override
         *  dict. Also runs the spelling-alias expansion. Use this for EVERY
         *  layered override dict. */
        internal fun remapProperOverrides(raw: Map<String, Hour.Part>, hourSlug: String): Map<String, Hour.Part> {
            val o = expandedOverrides(raw).toMutableMap()
            val ant1 = o["ant_1"]
            val ant2 = o["ant_2"]
            val ant3 = o["ant_3"]
            // Canticle antiphons must never sit on the Matins nocturn slots.
            o.remove("ant_1"); o.remove("ant_2"); o.remove("ant_3")

            when (hourSlug) {
                "matutinum" -> {
                    // Nocturn antiphons from "Ant Matutinum": one chunk per nocturn.
                    val lats = latLines(o["ant_matutinum"])
                    if (lats.isNotEmpty()) {
                        val engs = engLines(o["ant_matutinum"])
                        val per = maxOf(1, (lats.size + 2) / 3)
                        for (n in 0 until 3) {
                            val slice = lats.drop(n * per).take(per)
                            if (slice.isEmpty()) continue
                            val engSlice = engs.drop(n * per).take(per)
                            o["ant_${n + 1}"] = antiphonPart(
                                slice.joinToString("\n"),
                                if (engSlice.isEmpty()) null else engSlice.joinToString("\n"),
                                "Antiphon", "ant_${n + 1}",
                            )
                        }
                    }
                }

                "laudes" -> {
                    // A multi-line "Ant Laudes" is the five psalm antiphons; a
                    // single-line one (curated communes) is the Benedictus antiphon.
                    o["ant_laudes"]?.let { al ->
                        if (latLines(al).size >= 2) {
                            setPsalmAntiphons("laudes", al, o)
                            o.remove("ant_laudes")
                        }
                    }
                    if ("ant_laudes" !in o && ant2 != null) {
                        o["ant_laudes"] = rekeyed(ant2, "ant_laudes")
                    }
                    // Lauds versicle is DO's "Versum 2" (Versum 1 is 1st Vespers').
                    val v = o["versum_2"] ?: raw["versum_2"]
                    if (v != null) o["versum_1"] = rekeyed(v, "versum_1")
                    o.remove("versum_2")
                }

                "vesperae" -> {
                    // Psalm antiphons: the 2nd-Vespers list (Ant Vespera 3)
                    // wins over the 1st-Vespers/shared list (Ant Vespera).
                    val list = o["ant_vespera_3"] ?: o["ant_vespera_3c"]
                    if (list != null) {
                        setPsalmAntiphons("vesperae", list, o)
                    } else {
                        o["ant_vespera"]?.let { av ->
                            if (latLines(av).size >= 2) setPsalmAntiphons("vesperae", av, o)
                        }
                    }
                    o["ant_vespera"]?.let { av ->
                        if (latLines(av).size >= 2) o.remove("ant_vespera")
                    }
                    o.remove("ant_vespera_3"); o.remove("ant_vespera_3c")
                    // Magnificat antiphon: DO's Ant 3 (2nd Vespers), else Ant 1.
                    if ("ant_vespera" !in o) {
                        (ant3 ?: ant1)?.let { o["ant_vespera"] = rekeyed(it, "ant_vespera") }
                    }
                    // Vespers versicle: Versum 3 (2nd Vespers), else Versum 1
                    // (1st Vespers -- usually identical); DO's Versum 2 is the
                    // LAUDS versicle and must not land here.
                    val v = raw["versum_3"] ?: raw["versum_1"]
                    if (v != null) o["versum_2"] = rekeyed(v, "versum_2") else o.remove("versum_2")
                }
            }
            return o
        }

        /** "pent10-3" -> "pent10-0": the Sunday whose week the feria belongs to. */
        internal fun precedingSundayKey(temporalKey: String): String? {
            val dashIdx = temporalKey.lastIndexOf('-')
            if (dashIdx == -1) return null
            val daySuffix = temporalKey.substring(dashIdx + 1)
            val dayNum = daySuffix.toIntOrNull() ?: return null
            if (daySuffix.length != 1 || dayNum !in 1..6) return null
            return temporalKey.substring(0, dashIdx + 1) + "0"
        }

        /** Mapping from a psalm part's variationKey to the antiphon-override
         *  key that carries its proper antiphon. Lauds has psalm1-3,
         *  canticle1, psalm4; Vespers psalm1-5; Matins' antiphon keys are
         *  offset by one because matutinum.psalm1 is the invariable Venite.
         *  Shared with ContentStore.applyProperOverrides. */
        internal val PSALM_TO_ANTIPHON_KEY: Map<String, String> = mapOf(
            "laudes.psalm1"    to "laudes.antiphon.psalm1",
            "laudes.psalm2"    to "laudes.antiphon.psalm2",
            "laudes.psalm3"    to "laudes.antiphon.psalm3",
            "laudes.canticle1" to "laudes.antiphon.psalm4",
            "laudes.psalm4"    to "laudes.antiphon.psalm5",
            "vesperae.psalm1"  to "vesperae.antiphon.psalm1",
            "vesperae.psalm2"  to "vesperae.antiphon.psalm2",
            "vesperae.psalm3"  to "vesperae.antiphon.psalm3",
            "vesperae.psalm4"  to "vesperae.antiphon.psalm4",
            "vesperae.psalm5"  to "vesperae.antiphon.psalm5",
            "matutinum.psalm2"  to "matutinum.antiphon.psalm1",
            "matutinum.psalm3"  to "matutinum.antiphon.psalm2",
            "matutinum.psalm4"  to "matutinum.antiphon.psalm3",
            "matutinum.psalm5"  to "matutinum.antiphon.psalm4",
            "matutinum.psalm6"  to "matutinum.antiphon.psalm5",
            "matutinum.psalm7"  to "matutinum.antiphon.psalm6",
            "matutinum.psalm8"  to "matutinum.antiphon.psalm7",
            "matutinum.psalm9"  to "matutinum.antiphon.psalm8",
            "matutinum.psalm10" to "matutinum.antiphon.psalm9",
        )

        /** Hours whose collect is the collect OF THE DAY. Prime and Compline
         *  are absent on purpose: their collects are invariable (keyed
         *  oratio_prima / oratio_completorium). */
        private val COLLECT_HOURS = setOf(
            "matutinum", "laudes", "tertia", "sexta", "nona", "vesperae",
        )

        /** Weekday-psalter keys that belong to the FERIAL office only. */
        private val FERIAL_ONLY_DAY_KEYS = setOf(
            "hymnus_laudes", "hymnus_vespera",
            "ant_laudes", "ant_vespera",
            "versum_1", "versum_2",
        )

        /** Convert a part's `ref` field to a psalter.json key, e.g. "Ps 109" -> "psalm109".
         *  Returns null for refs that don't map to a single psalm (canticles, ranges, etc.). */
        private fun psalterKey(ref: String): String? {
            val trimmed = ref.trim()
            val prefix = when {
                trimmed.startsWith("Ps ") -> "Ps "
                trimmed.startsWith("Psalm ") -> "Psalm "
                else -> return null
            }
            val numPart = trimmed.removePrefix(prefix).trim()
            val num = numPart.toIntOrNull() ?: return null
            return if (num in 1..150) "psalm$num" else null
        }

        private val dayKeys = listOf(
            "sunday", "monday", "tuesday", "wednesday",
            "thursday", "friday", "saturday",
        )

        private val HIGH_RANK_WEEKDAY_FEASTS = setOf(
            "christmas", "circumcision", "epiphany", "purification",
            "st-stephen", "st-john-evangelist", "holy-innocents",
            "easter-0-1", "easter-0-2", "easter-0-3", "easter-0-4", "easter-0-5", "easter-0-6",
            "easter-7-1", "easter-7-2", "easter-7-3", "easter-7-4", "easter-7-5", "easter-7-6",
            "ascension", "corpus-christi", "sacred-heart",
            "st-joseph", "annunciation", "st-joseph-worker",
            "sts-peter-paul", "nativity-john-baptist",
            "assumption", "nativity-bvm", "holy-rosary",
            "all-saints", "all-souls", "immaculate-conception",
            "holy-thursday", "good-friday", "holy-saturday",
        )

        /** The intercession versicles of the Preces Feriales (common to Lauds and Vespers). */
        private val PRECES_VERSICLES = listOf(
            Hour.Part.Verse(
                lat = "℣. Ego dixi: Dómine, miserére mei.\n℟. Sana ánimam meam quia peccávi tibi.",
                eng = "℣. I said: Lord, be merciful unto me.\n℟. Heal my soul, for I have sinned against Thee.",
            ),
            Hour.Part.Verse(
                lat = "℣. Convértere, Dómine, úsquequo?\n℟. Et deprecábilis esto super servos tuos.",
                eng = "℣. Turn Thee again, O Lord; how long will it be?\n℟. And be gracious unto Thy servants.",
            ),
            Hour.Part.Verse(
                lat = "℣. Fiat misericórdia tua, Dómine, super nos.\n℟. Quemádmodum sperávimus in te.",
                eng = "℣. Let Thy mercy, O Lord, be upon us.\n℟. As we have hoped in Thee.",
            ),
            Hour.Part.Verse(
                lat = "℣. Sacerdótes tui induántur justítiam.\n℟. Et sancti tui exsúltent.",
                eng = "℣. Let Thy priests be clothed with justice.\n℟. And may Thy saints rejoice.",
            ),
            Hour.Part.Verse(
                lat = "℣. Orémus pro beatíssimo Papa nostro N.\n℟. Dóminus consérvet eum, et vivíficet eum, et beátum fáciat eum in terra, et non tradat eum in ánimam inimicórum ejus.",
                eng = "℣. Let us pray for our most blessed Pope N.\n℟. The Lord preserve him and give him life, and make him blessed upon the earth: and deliver him not up to the will of his enemies.",
            ),
            Hour.Part.Verse(
                lat = "℣. Orémus et pro Antístite nostro N.\n℟. Stet et pascat in fortitúdine tua, Dómine, in sublimitáte nóminis tui.",
                eng = "℣. Let us pray for our Bishop N.\n℟. May he stand firm and care for us in the strength of the Lord, in the might of Thy name.",
            ),
            Hour.Part.Verse(
                lat = "℣. Salvum fac pópulum tuum, Dómine, et bénedic hereditáti tuæ.\n℟. Et rege eos, et extólle illos usque in ætérnum.",
                eng = "℣. O Lord, save Thy people, and bless Thine inheritance.\n℟. Govern them and lift them up for ever.",
            ),
            Hour.Part.Verse(
                lat = "℣. Meménto Congregatiónis tuæ.\n℟. Quam possedísti ab inítio.",
                eng = "℣. Remember Thy congregation.\n℟. Which Thou hast possessed from the beginning.",
            ),
            Hour.Part.Verse(
                lat = "℣. Fiat pax in virtúte tua.\n℟. Et abundántia in túrribus tuis.",
                eng = "℣. Let peace be in Thy strength.\n℟. And abundance in Thy towers.",
            ),
            Hour.Part.Verse(
                lat = "℣. Orémus pro benefactóribus nostris.\n℟. Retribúere dignáre, Dómine, ómnibus, nobis bona faciéntibus propter nomen tuum, vitam ætérnam. Amen.",
                eng = "℣. Let us pray for our benefactors.\n℟. O Lord, for Thy name's sake, deign to reward with eternal life all who do us good. Amen.",
            ),
            Hour.Part.Verse(
                lat = "℣. Orémus pro fidélibus defúnctis.\n℟. Réquiem ætérnam dona eis, Dómine, et lux perpétua lúceat eis.",
                eng = "℣. Let us pray for the faithful departed.\n℟. Eternal rest grant unto them, O Lord, and let perpetual light shine upon them.",
            ),
            Hour.Part.Verse(
                lat = "℣. Requiéscant in pace.\n℟. Amen.",
                eng = "℣. May they rest in peace.\n℟. Amen.",
            ),
            Hour.Part.Verse(
                lat = "℣. Pro frátribus nostris abséntibus.\n℟. Salvos fac servos tuos, Deus meus, sperántes in te.",
                eng = "℣. Let us pray for our absent brothers.\n℟. Save Thy servants, O God, who put their trust in Thee.",
            ),
            Hour.Part.Verse(
                lat = "℣. Pro afflíctis et captívis.\n℟. Líbera eos, Deus Israël, ex ómnibus tribulatiónibus suis.",
                eng = "℣. Let us pray for the afflicted and imprisoned.\n℟. Deliver them, God of Israel, from all their tribulations.",
            ),
            Hour.Part.Verse(
                lat = "℣. Mitte eis, Dómine, auxílium de sancto.\n℟. Et de Sion tuére eos.",
                eng = "℣. O Lord, send them help from Thy sanctuary.\n℟. And defend them out of Sion.",
            ),
            Hour.Part.Verse(
                lat = "℣. Dómine, exáudi oratiónem meam.\n℟. Et clamor meus ad te véniat.",
                eng = "℣. O Lord, hear my prayer.\n℟. And let my cry come unto Thee.",
            ),
        )

        /** Concluding versicles after the psalm in Preces Feriales. */
        private val CONCLUDING_VERSICLES = listOf(
            Hour.Part.Verse(
                lat = "℣. Dómine, Deus virtútum, convérte nos.\n℟. Et osténde fáciem tuam, et salvi érimus.",
                eng = "℣. Turn us again, O Lord, God of Hosts.\n℟. Show us Thy face, and we shall be whole.",
            ),
            Hour.Part.Verse(
                lat = "℣. Exsúrge, Christe, ádjuva nos.\n℟. Et líbera nos propter nomen tuum.",
                eng = "℣. Arise, O Christ, and help us.\n℟. And redeem us for Thy name's sake.",
            ),
        )
    }
}
