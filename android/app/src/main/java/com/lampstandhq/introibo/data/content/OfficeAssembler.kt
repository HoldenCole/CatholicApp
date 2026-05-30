package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.LiturgicalSeason
import com.lampstandhq.introibo.data.liturgical.MarianAntiphon
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.MarianAntiphonData

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
    fun assemble(template: Hour, context: LiturgicalContext): Hour {
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
        val temporalOverrides = expandedOverrides(rawTemporalOverrides)

        val assembledParts = template.parts.map { part ->
            val key = part.variationKey ?: return@map part

            if (part.type == "marian") {
                return@map marianPart(context.marian, fallback = part)
            }

            // Temporal propers (highest priority for non-psalm parts)
            temporalOverrides[key]?.let { return@map it }

            if (part.type == "hymn") {
                seasonOverrides[key]?.let { return@map it }
            }

            dayOverrides[key]?.let { return@map it }

            part
        }

        // Inline psalm text from psalter.json for any psalm part that has
        // a ref but no verses (or empty verses).
        val psalmInlined = assembledParts.map { inlinePsalmText(it) }

        // Apply temporal per-psalm antiphon overrides.
        val antiphonApplied = psalmInlined.map { part ->
            val key = part.variationKey ?: return@map part
            val hourPrefix = key.substringBefore(".")
            // Lauds: psalm1, psalm2, psalm3, canticle1, psalm4 (canticle in middle)
            // Vespers: psalm1-psalm5 (all psalms). Antiphon slots are always 1-5.
            val antKey = when {
                key.endsWith(".psalm1") -> "$hourPrefix.antiphon.psalm1"
                key.endsWith(".psalm2") -> "$hourPrefix.antiphon.psalm2"
                key.endsWith(".psalm3") -> "$hourPrefix.antiphon.psalm3"
                key.endsWith(".canticle1") -> "$hourPrefix.antiphon.psalm4"
                key.endsWith(".psalm4") ->
                    // Lauds psalm4 is the 5th element; Vespers psalm4 is the 4th
                    if (hourPrefix == "laudes") "$hourPrefix.antiphon.psalm5"
                    else "$hourPrefix.antiphon.psalm4"
                key.endsWith(".psalm5") -> "$hourPrefix.antiphon.psalm5"
                else -> null
            }
            val antOverride = antKey?.let { temporalOverrides[it] }
            if (antOverride != null) {
                part.copy(antiphonLat = antOverride.lat, antiphonEng = antOverride.eng)
            } else {
                part
            }
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

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        val filteredParts = if (template.slug == "matutinum") {
            filterMatinsParts(lausTibiApplied, context)
        } else if (template.slug == "prima" && isOctave && context.dayOfWeek != 0) {
            // Easter/Pentecost octave festal Prime: Ps 53, 118 pars I,
            // 118 pars II -- drop Psalm 117 (prima.psalm2 in the template).
            lausTibiApplied.filter { it.variationKey != "prima.psalm2" }
        } else {
            lausTibiApplied
        }

        // Insert Preces Feriales for Lauds/Vespers on qualifying ferial days.
        // When Preces are not said, also remove the standalone Pater Noster
        // that precedes the Collect (it is only said as part of the Preces).
        val precesApplied = if (
            (template.slug == "laudes" || template.slug == "vesperae")
            && shouldIncludePreces(context)
        ) {
            insertPreces(filteredParts, template.slug)
        } else if (template.slug == "laudes" || template.slug == "vesperae") {
            filteredParts.filter { part ->
                !(part.type == "pater" && part.variationKey.isNullOrEmpty()
                    && !(part.label ?: "").contains("Ave"))
            }
        } else {
            filteredParts
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
    private fun filterMatinsParts(parts: List<Hour.Part>, context: LiturgicalContext): List<Hour.Part> {
        val isWeekday = context.dayOfWeek != 0
        val isHighRankFeast = isWeekday
            && context.properSlug?.let { it in HIGH_RANK_WEEKDAY_FEASTS } == true
        val useThreeNocturns = !isWeekday || isHighRankFeast

        return if (!useThreeNocturns) {
            filterToOneNocturn(parts)
        } else {
            if (shouldOmitTeDeum(context)) {
                parts.filter { !isTeDeum(it) }
            } else {
                parts
            }
        }
    }

    /**
     * Reduce Matins to 1 nocturn by removing everything from the
     * "In II Nocturno" heading through the Te Deum (inclusive).
     * Keeps: Invitatory, Hymn, Nocturn I, Capitulum, Collect, Closing.
     */
    private fun filterToOneNocturn(parts: List<Hour.Part>): List<Hour.Part> {
        // Find the index of "In II Nocturno" heading.
        val nocturn2Index = parts.indexOfFirst { part ->
            part.type == "heading" && (part.label ?: "").contains("II Noct")
        }
        if (nocturn2Index == -1) {
            // Template doesn't have Nocturn II -- nothing to remove.
            return parts
        }

        // Find the Te Deum (canticle with "Te Deum" in label).
        val teDeumIndex = parts.indexOfFirst { isTeDeum(it) }

        // Keep parts before Nocturn II.
        val kept = parts.subList(0, nocturn2Index).toMutableList()

        // Append parts after Te Deum (or after Nocturn III's last element
        // if Te Deum is somehow missing). The Te Deum itself is omitted
        // in 1-nocturn Matins.
        if (teDeumIndex != -1) {
            // Everything after the Te Deum line
            if (teDeumIndex + 1 < parts.size) {
                kept.addAll(parts.subList(teDeumIndex + 1, parts.size))
            }
        } else {
            // Fallback: find the end of Nocturn III by looking for the
            // capitulum, collect, or closing elements.
            val capIndex = parts.indexOfFirst { part ->
                part.type == "capitulum" || part.type == "collect" || part.type == "closing"
            }
            if (capIndex != -1 && capIndex >= nocturn2Index) {
                kept.addAll(parts.subList(capIndex, parts.size))
            }
        }

        return kept
    }

    /**
     * Te Deum is omitted on Sundays during Septuagesima-tide, Lent, and Passiontide.
     * Septuagesima/Sexagesima/Quinquagesima Sundays are detected via properSlug.
     */
    private fun shouldOmitTeDeum(context: LiturgicalContext): Boolean {
        // Lent and Passion Sundays: always omit
        if (context.season == LiturgicalSeason.LENT || context.season == LiturgicalSeason.PASSION) {
            return true
        }

        // Pre-Lent Sundays (Septuagesima, Sexagesima, Quinquagesima)
        // are in PER_ANNUM by the season detector but have distinctive
        // properSlug values.
        val slug = context.properSlug
        if (slug != null) {
            val preLentSlugs = listOf("septuagesima", "sexagesima", "quinquagesima")
            if (slug in preLentSlugs) {
                return true
            }
        }

        return false
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
    // 1962 Breviary rubric: Preces are said at Lauds and Vespers on ferial
    // days (Mon-Sat) during Advent and Lent/Passiontide, provided no feast
    // of Double rank or higher is celebrated. They are NOT said on Sundays,
    // feast days (rank >= 3 / high-rank weekday feasts), during the Easter
    // or Pentecost octaves, or on days of obligation.

    /**
     * Determines whether Preces Feriales should be included in the Hour.
     */
    private fun shouldIncludePreces(context: LiturgicalContext): Boolean {
        // Never on Sundays
        if (context.dayOfWeek == 0) return false

        // Only during Advent, Lent, or Passiontide
        if (context.season != LiturgicalSeason.ADVENT
            && context.season != LiturgicalSeason.LENT
            && context.season != LiturgicalSeason.PASSION
        ) return false

        // Not on high-rank weekday feasts (equivalent to Double rank or higher)
        val slug = context.properSlug
        if (slug != null && slug in HIGH_RANK_WEEKDAY_FEASTS) {
            return false
        }

        return true
    }

    /**
     * Inserts the Preces Feriales parts into the assembled hour, placed
     * after the Collect and before the concluding versicle.
     */
    private fun insertPreces(parts: List<Hour.Part>, hour: String): List<Hour.Part> {
        val collectIndex = parts.indexOfLast { it.type == "collect" }
        if (collectIndex == -1) return parts

        val insertionIndex = collectIndex + 1
        val precesParts = makePrecesParts(hour)

        return parts.subList(0, insertionIndex) + precesParts + parts.subList(insertionIndex, parts.size)
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
            "hymnusm_vespera"          to "hymnus_vespera",
            "hymnus_vespera_3"         to "hymnus_vespera",
            "ant_vespera_3"            to "ant_vespera",
            "ant_vespera_3c"           to "ant_vespera",
            // Vespers -- capitulum variants (sanctoral, e.g. Christmas)
            "capitulum_vespera_1"      to "vesperae.capitulum",
            "capitulum_vespera_3"      to "vesperae.capitulum",
            // Matins -- variant hymn spelling & antiphon
            "hymnusm_matutinum"        to "hymnus_matutinum",
            "hymnus_matutinum_"        to "hymnus_matutinum",
            "ant_matutinum"            to "ant_1",
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
                eng = "℣. Let us pray for our benefactors.\n℟. O Lord, for Thy name’s sake, deign to reward with eternal life all who do us good. Amen.",
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
                eng = "℣. Arise, O Christ, and help us.\n℟. And redeem us for Thy name’s sake.",
            ),
        )
    }
}
