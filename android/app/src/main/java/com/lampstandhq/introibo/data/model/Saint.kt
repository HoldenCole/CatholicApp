package com.lampstandhq.introibo.data.model

import com.lampstandhq.introibo.data.links.RelatedLink
import kotlinx.serialization.Serializable

/**
 * Matches saints.json.
 */
@Serializable
data class Saint(
    val slug: String,
    val name: String,
    val title: String,
    val quote: String,
    val penance: String? = null,
    val penanceLatin: String? = null,
    val sections: List<Section>,
    val prayers: List<SaintPrayer>? = null,
    val related: List<RelatedLink>? = null,
) {
    @Serializable
    data class Section(
        val lat: String,
        val eng: String,
        val practices: List<Practice>,
    )

    @Serializable
    data class Practice(
        val t: String,
        val d: String,
    )

    @Serializable
    data class SaintPrayer(
        val title: String,
        val latin: String? = null,
        val eng: String,
        val note: String? = null,
    )
}
