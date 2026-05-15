package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

/**
 * Matches propers.json — Mass propers for a given day/feast.
 */
@Serializable
data class MassProper(
    val slug: String,
    val title: String,
    val english: String,
    val rank: Int,
    val color: String,
    val season: String? = null,
    val introit: ProperText,
    val collect: ProperText,
    val epistle: ProperReading,
    val gradual: ProperText? = null,
    val alleluia: ProperText? = null,
    val tract: ProperText? = null,
    val sequence: ProperText? = null,
    val gospel: ProperReading,
    val offertory: ProperText,
    val secret: ProperText,
    val communion: ProperText,
    val postcommunion: ProperText,
    val preface: String? = null,
)

@Serializable
data class ProperText(
    val lat: String,
    val eng: String,
)

@Serializable
data class ProperReading(
    val ref: String,
    val lat: String,
    val eng: String,
)
