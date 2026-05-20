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
    private val temporalPropers: Map<String, Map<String, Hour.Part>> = emptyMap(),
    private val marianAntiphons: List<MarianAntiphonData>,
) {
    fun assemble(template: Hour, context: LiturgicalContext): Hour {
        val dayKey = dayKeys[context.dayOfWeek]
        val seasonKey = seasonString(context.season)
        val dayOverrides = weeklyPsalter[dayKey] ?: emptyMap()
        val seasonOverrides = seasonalHymns[seasonKey] ?: emptyMap()
        val temporalOverrides = context.temporalKey?.let { temporalPropers[it] } ?: emptyMap()

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

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        val finalParts = if (template.slug == "matutinum") {
            filterMatinsParts(assembledParts, context)
        } else {
            assembledParts
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
            // Template doesn't have Nocturn II — nothing to remove.
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

    companion object {
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
    }
}
