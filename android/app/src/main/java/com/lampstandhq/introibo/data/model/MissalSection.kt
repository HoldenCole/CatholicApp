package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

/**
 * Matches missal.json.
 * 13 sections of the Ordinary of the Mass, in order.
 */
@Serializable
data class MissalSection(
    val slug: String,
    val label: String? = null,
    val title: String,
    val english: String? = null,
    val body: List<Line>,
) {
    @Serializable
    data class Line(
        val lat: String,
        val eng: String,
        val rubric: String? = null,
    )
}
