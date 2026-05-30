package com.lampstandhq.introibo.data.model

import com.lampstandhq.introibo.data.links.RelatedLink
import kotlinx.serialization.Serializable

/**
 * Matches reference.json. All fields except slug/title/cat/summary
 * are optional per-entry.
 */
@Serializable
data class ReferenceEntry(
    val slug: String,
    val title: String,
    val latin: String? = null,
    val cat: String,                 // Category label
    val summary: String,
    val history: String? = null,
    val practice: String? = null,
    val notes: String? = null,
    val scripture: Scripture? = null,
    val related: List<RelatedLink>? = null,
) {
    @Serializable
    data class Scripture(
        val ref: String,
        val lat: String,
        val eng: String,
    )
}
