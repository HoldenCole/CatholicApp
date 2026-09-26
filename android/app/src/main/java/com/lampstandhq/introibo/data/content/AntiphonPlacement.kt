package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.storage.settings.MissalRite

/**
 * Where the antiphon goes around its psalm(s), after Divinum Officium's
 * `antetpsalm`: an antiphon is said before its psalm — or before the first of
 * the psalms it covers — and repeated whole (the asterisk dropped) after the
 * last of them. Whether the first saying is the whole antiphon or only its
 * incipit (up to the asterisk) depends on the books and the rank:
 *
 *  - Rubrics 1960: every antiphon is doubled (said whole both times).
 *  - Older books: doubled at Matins, Lauds and Vespers on doubles (not in the
 *    Office of the Dead, nor when the rule says "Matins simplex"); the
 *    Benedictus/Magnificat antiphon on doubles and the Advent O antiphons at
 *    Vespers (Dec 17-23); never at Prime, the little hours and Compline.
 *
 * The hour model keeps the antiphon once (on the psalm, or as its own part);
 * [runs] finds the psalm runs each antiphon covers and [repeats] gives the
 * views the antiphon to print after each run's last psalm. The invitatory is
 * not an antiphon of this kind (it is woven into the Venite), and the Special
 * scripts of the Triduum and Holy Saturday spell their repeats out
 * themselves — those are left alone.
 *
 * Swift mirror: Introibo/Data/AntiphonPlacement.swift
 */
object AntiphonPlacement {

    private val psalmTypes = setOf("psalm", "canticle")
    private val canticleKeys = setOf("ant_laudes", "ant_vespera")
    private val ASTERISK_CUT = Regex("""\s+\*.*""", RegexOption.DOT_MATCHES_ALL)
    private val ASTERISK_DROP = Regex("""\s*\*\s*""")

    /** The antiphon as it is intoned before the psalm: up to the asterisk, a final comma made a period. */
    fun intoned(text: String): String {
        val head = ASTERISK_CUT.replace(text, "").trim()
        if (head.isEmpty()) return text.trim()
        return if (head.endsWith(",")) head.dropLast(1) + "." else head
    }

    /** The whole antiphon as it is repeated after the psalm(s): the asterisk dropped. */
    fun whole(text: String): String = ASTERISK_DROP.replace(text, " ").replace(Regex(" {2,}"), " ").trim()

    /** One antiphon and the consecutive psalm parts it covers. */
    class Run(
        /** Index of the part that carries the antiphon (a psalm with its own, or a standalone antiphon part). */
        val head: Int,
        /** Index of the last psalm/canticle under the antiphon. */
        val last: Int,
        val lat: String,
        val eng: String?,
        /** The next part already prints this antiphon (a Special script): nothing to repeat. */
        val literalAfter: Boolean,
    )

    fun runs(parts: List<Hour.Part>): List<Run> {
        val out = ArrayList<Run>()
        var head = -1
        var lat: String? = null
        var eng: String? = null
        var i = 0
        while (i < parts.size) {
            val p = parts[i]
            val next = parts.getOrNull(i + 1)
            when {
                p.type == "antiphon" -> {
                    head = -1; lat = null
                    val opensRun = next != null && next.type in psalmTypes && next.antiphonLat.isNullOrEmpty()
                    if (opensRun && p.variationKey != "invit" && !p.lat.isNullOrBlank()) {
                        head = i; lat = p.lat; eng = p.eng
                    }
                }
                p.type in psalmTypes -> {
                    if (!p.antiphonLat.isNullOrEmpty()) { head = i; lat = p.antiphonLat; eng = p.antiphonEng }
                    if (lat != null) {
                        val continues = next != null && next.type in psalmTypes && next.antiphonLat.isNullOrEmpty()
                        if (!continues) {
                            val literal = next != null && next.type == "antiphon" && fold(next.lat) == fold(lat)
                            out.add(Run(head, i, lat, eng, literal))
                            head = -1; lat = null
                        }
                    }
                }
                else -> { head = -1; lat = null }
            }
            i++
        }
        return out
    }

    /** For each part index, the antiphon (Latin, vernacular) to print after that part. */
    fun repeats(parts: List<Hour.Part>): Map<Int, Pair<String, String?>> =
        runs(parts).filter { !it.literalAfter }.associate { it.last to (whole(it.lat) to it.eng?.let(::whole)) }

    /**
     * Marks the antiphons the older books intone only (DO's `$duplexf`). The
     * 1960 books double every antiphon; parts without a variation key come
     * from DO's literal scripts and are left as written.
     */
    fun markIntonation(parts: List<Hour.Part>, hourSlug: String, office: OfficeRubrics.Office, rite: MissalRite): List<Hour.Part> {
        if (rite == MissalRite.RITE_1962) return parts
        val dead = office.communeKey == "C12"
        val doubledPsalms = when (hourSlug) {
            "matutinum" -> office.duplex > 2 && !dead && !office.ruleHas("Matins simplex")
            "laudes", "vesperae" -> office.duplex > 2 && !dead
            else -> false
        }
        val oAntiphon = hourSlug == "vesperae" && office.temporal && office.date.monthValue == 12 && office.date.dayOfMonth in 17..23
        val doubledCanticle = office.duplex > 2 || oAntiphon
        val heads = runs(parts).map { it.head }.toSet()
        if (heads.isEmpty()) return parts
        return parts.mapIndexed { i, p ->
            if (i !in heads || p.variationKey == null) p
            else {
                val doubled = if (p.type == "antiphon" && p.variationKey in canticleKeys) doubledCanticle else doubledPsalms
                if (doubled) p else p.copy(antiphonIntoned = true)
            }
        }
    }

    private fun fold(s: String?): String =
        (s ?: "").lowercase().replace("*", "").replace(Regex("""[\s.,:;!?]+"""), " ").trim()
}
