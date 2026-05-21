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
    // Optional propers using DO's Latin field names. Currently absent from
    // missal_tempora.json / missal_sanctoral.json but threaded so that any
    // future data additions surface in the rendered MassProper.
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

        return MassProper(
            slug = key,
            title = officium ?: key,
            english = officium ?: key,
            rank = legacyRank,
            color = ordo?.color ?: "",
            season = ordo?.season,
            introit = intro,
            collect = collect,
            epistle = ProperReading(ref = ep.ref ?: "", lat = ep.lat, eng = ep.eng),
            gradual = graduale,
            alleluia = alleluia,
            tract = tractus,
            sequence = sequentia,
            gospel = ProperReading(ref = gosp.ref ?: "", lat = gosp.lat, eng = gosp.eng),
            offertory = off,
            secret = sec,
            communion = comm,
            postcommunion = postcomm,
            preface = translatePrefaceCode(rule?.preface),
            glorOverride = rule?.gloria,
            credoOverride = rule?.credo,
        )
    }

    companion object {
        /** Translates DivinumOfficium preface codes to slug suffixes in missal.json. */
        fun translatePrefaceCode(code: String?): String? {
            if (code.isNullOrEmpty()) return null
            val base = code.split('=', ';').firstOrNull()?.trim() ?: code
            return when (base) {
                "Nat", "Nativitate" -> "nativity"
                "Pasch", "Pasc", "Paschalis", "Paschali" -> "easter"
                "Quad", "Quadragesimale" -> "lent"
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
