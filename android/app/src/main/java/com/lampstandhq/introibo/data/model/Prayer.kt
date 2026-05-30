package com.lampstandhq.introibo.data.model

import com.lampstandhq.introibo.data.links.RelatedLink
import kotlinx.serialization.Serializable

/**
 * A single prayer. Matches the shape of prayers.json.
 */
@Serializable
data class Prayer(
    val slug: String,
    val title: String,
    val eng: String,
    val category: String,
    val note: String? = null,
    val occasions: List<String>? = null,
    val related: List<RelatedLink>? = null,
    val lines: List<Line>,
) {
    @Serializable
    data class Line(
        val lat: String,
        val eng: String,
    )
}
