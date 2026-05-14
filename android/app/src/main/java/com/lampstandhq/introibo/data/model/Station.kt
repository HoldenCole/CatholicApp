package com.lampstandhq.introibo.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Matches stations.json — 14 stations, ordered.
 */
@Serializable
data class Station(
    val station: String,     // Roman numeral I...XIV
    val title: String,
    val latin: String,
    val med: String,         // Meditation
    val mood: String,        // "" | "mood-mother" | "mood-death" | "mood-tomb"
    @SerialName("stabat_lat")
    val stabatLat: String,
    @SerialName("stabat_eng")
    val stabatEng: String,
)
