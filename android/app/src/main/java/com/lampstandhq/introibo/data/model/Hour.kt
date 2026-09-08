package com.lampstandhq.introibo.data.model

import com.lampstandhq.introibo.data.links.RelatedLink
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Matches hours.json — the 8 canonical hours of the 1962 Roman Breviary.
 */
@Serializable
data class Hour(
    val slug: String,
    val name: String,        // Latin name (Matutinum, Laudes, ...)
    val eng: String,         // English name
    val time: String,        // "at midnight", "at dawn", ...
    val hour: Int,           // 0-23
    val minute: Int,
    val glyph: String,       // Single-letter dial glyph (M, L, I, III...)
    val order: Int,          // Roman order for Hora I/II/...
    val intro: String,       // Short prose introduction
    val parts: List<Part>,
    val related: List<RelatedLink>? = null,
) {
    /**
     * Heterogeneous parts. We decode into a sum-type-ish class that
     * carries whichever fields are present; views switch on [type].
     */
    @Serializable
    data class Part(
        val type: String,
        val label: String? = null,
        val title: String? = null,
        val ref: String? = null,
        val lat: String? = null,
        val eng: String? = null,
        val latR: String? = null,
        val engR: String? = null,
        val v1Lat: String? = null,
        val v1Eng: String? = null,
        val r1Lat: String? = null,
        val r1Eng: String? = null,
        val v2Lat: String? = null,
        val v2Eng: String? = null,
        val r2Lat: String? = null,
        val r2Eng: String? = null,
        val verses: List<Verse>? = null,
        val season: String? = null,
        val engBody: String? = null,
        val variationKey: String? = null,
        val antiphonLat: String? = null,
        val antiphonEng: String? = null,
    ) {
        @Serializable
        data class Verse(
            val lat: String,
            val eng: String,
        )
    }
}

/**
 * Matches marian_antiphons.json.
 */
@Serializable
data class MarianAntiphonData(
    val slug: String,
    val title: String,
    val eng: String,
    val season: String,
    val lat: String,
    val engBody: String,
    // The ℣/℟ and Orémus that follow the antiphon at Compline.
    @SerialName("versicle_lat") val versicleLat: String? = null,
    @SerialName("versicle_eng") val versicleEng: String? = null,
    @SerialName("collect_lat") val collectLat: String? = null,
    @SerialName("collect_eng") val collectEng: String? = null,
    // Alma Redemptóris only: the forms used from Christmas to Feb 1.
    @SerialName("versicle_lat_christmas") val versicleLatChristmas: String? = null,
    @SerialName("versicle_eng_christmas") val versicleEngChristmas: String? = null,
    @SerialName("collect_lat_christmas") val collectLatChristmas: String? = null,
    @SerialName("collect_eng_christmas") val collectEngChristmas: String? = null,
)
