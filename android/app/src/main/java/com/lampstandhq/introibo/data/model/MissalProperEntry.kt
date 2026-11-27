package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

@Serializable
data class MissalProperEntry(
    val officium: String? = null,
    val rank: Double? = null,
    val rule: MissalRule? = null,
    val introitus: ProperText? = null,
    val oratio: ProperText? = null,
    val lectio: ProperText? = null,
    val graduale: ProperText? = null,
    val evangelium: ProperText? = null,
    val offertorium: ProperText? = null,
    val secreta: ProperText? = null,
    val communio: ProperText? = null,
    val postcommunio: ProperText? = null,
    // DO's seasonal forms of the Gradual: gradualeP in Paschaltide, tractus
    // from Septuagesima to Holy Saturday (each with its Gradual verses, as
    // DO's getitem() takes it in place of [Graduale]).
    val gradualeP: ProperText? = null,
    val alleluia: ProperText? = null,
    val tractus: ProperText? = null,
    val sequentia: ProperText? = null,
) {
    @Serializable
    data class MissalRule(
        val gloria: Boolean? = null,
        val credo: Boolean? = null,
        val preface: String? = null,
        // Optional redirect to another formulary used as a fallback when this
        // entry omits the Mass propers. Format: "Sancti/12-25m3", "Tempora/Epi3-0",
        // "C5" (commune key), or a bare missal key like "epi3-0".
        val commune: String? = null,
    )

    fun toMassProper(key: String, ordo: OrdoEntry? = null): MassProper? {
        val intro = introitus ?: return null
        val collect = oratio ?: return null
        val ep = lectio ?: return null
        val gosp = evangelium ?: return null
        val off = offertorium ?: return null
        val sec = secreta ?: return null
        val comm = communio ?: return null
        val postcomm = postcommunio ?: return null

        // DO rank scale: 1.0=ferial, 7.0=highest. Legacy: 1=highest, 5=ferial.
        val doRank = rank ?: 0.0
        val legacyRank = when {
            doRank >= 6.0 -> 1
            doRank >= 5.0 -> 2
            doRank >= 4.0 -> 3
            doRank >= 3.0 -> 4
            else -> 5
        }

        val latinTitle = officium ?: key
        val season = ordo?.season
        val paschal = season == "easter"
        // The Gradual the season takes (DO's getitem): the Paschal form in
        // Eastertide, the Tract from Septuagesima, otherwise the Gradual.
        val gradualForSeason = when {
            paschal && gradualeP != null -> gradualeP
            (season == "lent" || season == "pre-lent") && tractus != null -> tractus
            else -> graduale
        }
        val lenten = season == "lent" || season == "pre-lent"
        val a: (ProperText) -> ProperText = { seasonalAlleluia(it, paschal, lenten) }

        return MassProper(
            slug = key,
            title = latinTitle,
            english = latinTitle,
            rank = legacyRank,
            color = ordo?.color ?: "",
            season = ordo?.season,
            introit = a(intro),
            collect = collect,
            epistle = ProperReading(ref = ep.ref ?: "", lat = ep.lat, eng = ep.eng),
            gradual = gradualForSeason?.let(a),
            alleluia = alleluia,
            tract = null,
            sequence = sequentia,
            gospel = ProperReading(ref = gosp.ref ?: "", lat = gosp.lat, eng = gosp.eng),
            offertory = a(off),
            secret = sec,
            communion = a(comm),
            postcommunion = postcomm,
            preface = translatePrefaceCode(rule?.preface),
            glorOverride = rule?.gloria,
            credoOverride = rule?.credo,
        )
    }

    companion object {
        /** The bracketed alleluias of the Commons, "(Allelúja, allelúja.)":
         *  said in Paschaltide (the brackets dropped), left out otherwise, as
         *  DO's getitem() does. Latin, English, Spanish and French forms. */
        private val bracketedAlleluia = Regex("""\s*\(((?:Al+[eé]l[uú][ij]a|Aleluya)[^()]*)\)""", RegexOption.IGNORE_CASE)

        fun paschalAlleluia(text: String, paschal: Boolean): String =
            if (paschal) bracketedAlleluia.replace(text) { " " + it.groupValues[1] }
            else bracketedAlleluia.replace(text, "")

        /** A chant's closing alleluia ("… eórum, allelúja."), left out from
         *  Septuagesima to Holy Saturday as DO's "(sed post Septuagesimam
         *  dicitur)" does. A line that is nothing but alleluias stays. */
        private val closingAlleluia = Regex(
            """[,;:.]?\s*(?:(?:Al+[eé]l[uú][ij]a|Aleluya)[,.]?\s*)+$""", RegexOption.IGNORE_CASE)
        private val onlyAlleluia = Regex(
            """^\s*(?:V\.\s*)?(?:(?:Al+[eé]l[uú][ij]a|Aleluya)[,.]?\s*)+$""", RegexOption.IGNORE_CASE)

        fun lentenAlleluia(text: String): String = text.split("\n").joinToString("\n") { line ->
            if (onlyAlleluia.matches(line) || !closingAlleluia.containsMatchIn(line)) line
            else closingAlleluia.replace(line, "").trimEnd().let { if (it.endsWith(".") || it.endsWith("!") || it.endsWith("?")) it else "$it." }
        }

        fun seasonalAlleluia(p: ProperText, paschal: Boolean, lenten: Boolean): ProperText {
            fun t(x: String): String = paschalAlleluia(x, paschal).let { if (lenten) lentenAlleluia(it) else it }
            return p.copy(lat = t(p.lat), eng = t(p.eng))
        }

        /** Translates DivinumOfficium preface codes to slug suffixes in missal.json. */
        fun translatePrefaceCode(code: String?): String? {
            if (code.isNullOrEmpty()) return null
            val base = code.split('=', ';').firstOrNull()?.trim() ?: code
            return when (base) {
                "Nat", "Nativitate" -> "nativity"
                "Pasch", "Pasc", "Paschalis", "Paschali" -> "easter"
                "Quad", "Quadragesimale" -> "lent"
                "Quad5" -> "cross"
                "Asc", "Ascensione" -> "ascension"
                "Spiritu", "Pentecostes" -> "pentecost"
                "Epi", "Epiphania" -> "epiphany"
                "Trinitate", "Trinitatis" -> "trinity"
                "Joseph", "Josephi" -> "joseph"
                "Maria", "BMV", "Mariae" -> "bvm"
                "Apos", "Apostolis", "Apostolorum" -> "apostles"
                "Cruc", "Cruce", "Crucis" -> "cross"
                "Adv", "Adventus" -> "advent"
                "Requiem", "Defunctorum" -> "requiem"
                "Cord", "CordJesu", "Cordis" -> "sacred-heart"
                "Regis", "ChristiRegis", "Rex" -> "christ-king"
                "Communis", "Common", "" -> null
                else -> null
            }
        }
    }
}

@Serializable
data class OrdoEntry(
    val temporal: String? = null,
    val sanctoral: String? = null,
    val winner: String,
    val winnerKey: String,
    val rank: Double,
    val name: String,
    val color: String,
    val season: String,
    val commemoration: String? = null,
)
