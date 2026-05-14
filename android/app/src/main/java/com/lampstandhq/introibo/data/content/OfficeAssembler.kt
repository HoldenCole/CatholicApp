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
    private val marianAntiphons: List<MarianAntiphonData>,
) {
    fun assemble(template: Hour, context: LiturgicalContext): Hour {
        val dayKey = dayKeys[context.dayOfWeek]
        val seasonKey = seasonString(context.season)
        val dayOverrides = weeklyPsalter[dayKey] ?: emptyMap()
        val seasonOverrides = seasonalHymns[seasonKey] ?: emptyMap()

        val assembledParts = template.parts.map { part ->
            val key = part.variationKey ?: return@map part

            if (part.type == "marian") {
                return@map marianPart(context.marian, fallback = part)
            }

            if (part.type == "hymn") {
                seasonOverrides[key]?.let { return@map it }
            }

            dayOverrides[key]?.let { return@map it }

            part
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
            parts = assembledParts,
        )
    }

    private fun seasonString(season: LiturgicalSeason): String = when (season) {
        LiturgicalSeason.ADVENT -> "advent"
        LiturgicalSeason.LENT -> "lent"
        LiturgicalSeason.PASSION -> "passion"
        LiturgicalSeason.EASTER -> "easter"
        LiturgicalSeason.CHRISTMAS -> "ordinary"
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
    }
}
