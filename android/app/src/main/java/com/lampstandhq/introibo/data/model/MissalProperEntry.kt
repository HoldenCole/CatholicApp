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
) {
    @Serializable
    data class MissalRule(
        val gloria: Boolean? = null,
        val credo: Boolean? = null,
        val preface: String? = null,
    )

    fun toMassProper(key: String): MassProper? {
        val intro = introitus ?: return null
        val collect = oratio ?: return null
        val ep = lectio ?: return null
        val gosp = evangelium ?: return null
        val off = offertorium ?: return null
        val sec = secreta ?: return null
        val comm = communio ?: return null
        val postcomm = postcommunio ?: return null
        return MassProper(
            slug = key,
            title = officium ?: key,
            english = officium ?: key,
            rank = rank?.toInt() ?: 0,
            color = "",
            introit = intro,
            collect = collect,
            epistle = ProperReading(ref = ep.ref ?: "", lat = ep.lat, eng = ep.eng),
            gradual = graduale,
            gospel = ProperReading(ref = gosp.ref ?: "", lat = gosp.lat, eng = gosp.eng),
            offertory = off,
            secret = sec,
            communion = comm,
            postcommunion = postcomm,
            preface = rule?.preface,
        )
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
