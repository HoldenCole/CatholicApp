package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

/**
 * Matches mysteries.json.
 * 3 sets (joyful, sorrowful, glorious), 5 mysteries each.
 */
@Serializable
data class MysterySetData(
    val slug: String,            // joyful | sorrowful | glorious
    val name: String,            // Mysteria Gaudiosa etc
    val english: String,         // Joyful Mysteries etc
    val mysteries: List<Mystery>,
)

@Serializable
data class Mystery(
    val num: String,             // "Mysterium Primum" etc
    val title: String,           // Latin title
    val eng: String,             // English title
    val ref: String,             // Scripture reference
    val body: String,            // Meditation paragraph
    val fruit: String,           // Fruit of the mystery
)

/**
 * Matches rosary_prayers.json.
 * The 7 core prayers needed for the Rosary (signum, credo, pater, ave,
 * gloria, fatima, salve), with Latin + English.
 */
@Serializable
data class RosaryPrayer(
    val slug: String,
    val title: String,
    val eng: String,
    val lines: List<Line>,
) {
    @Serializable
    data class Line(
        val lat: String,
        val eng: String,
    )
}
