package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

/**
 * Matches courses.json.
 */
@Serializable
data class Course(
    val slug: String,
    val num: Int,
    val title: String,
    val latin: String,
    val intro: String,
    val sections: List<Section>,
) {
    @Serializable
    data class Section(
        val type: String,            // lesson | tip | cards | summary | phrase | table
        val label: String? = null,
        val html: String? = null,    // present for lesson/tip/summary/phrase/table
        val note: String? = null,    // present for cards
        val items: List<Card>? = null, // present for cards
    ) {
        @Serializable
        data class Card(
            val lat: String? = null,
            val phon: String? = null,
            val eng: String? = null,
        )
    }
}
