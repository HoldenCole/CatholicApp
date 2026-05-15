package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

/**
 * Matches confession_examen.json.
 * Each commandment has its English commandment text, Latin form,
 * and a short list of self-examination questions.
 */
@Serializable
data class ExamenEntry(
    val num: String,         // Roman numeral I...X
    val commandment: String,
    val latin: String,
    val questions: List<String>,
)

/**
 * Matches confession_guides.json.
 * Two guided paths ("Liber I" guided, "Liber II" after St. Catherine).
 */
@Serializable
data class ConfessionGuide(
    val slug: String,
    val name: String,
    val title: String,
    val subtitle: String? = null,
    val steps: List<Step>,
) {
    @Serializable
    data class Step(
        val num: String,       // i, ii, iii, ...
        val title: String,
        val latin: String? = null,
        val body: String,
    )
}
