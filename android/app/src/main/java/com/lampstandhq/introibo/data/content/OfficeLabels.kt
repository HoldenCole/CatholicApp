package com.lampstandhq.introibo.data.content

/**
 * The vernacular form of the English headings the Office assembly gives some
 * of its parts ("Versicle", "Blessing before Léctio I", "Marian Antiphon;
 * Salve Regína"). The parts keep their English label, which the rubrics and
 * the versicle marks key on; only the heading drawn on screen is translated
 * (ui_strings office.label.*). Latin headings pass through untouched.
 *
 * iOS mirror: Introibo/Data/OfficeLabels.swift
 */
object OfficeLabels {
    private val exact = mapOf(
        "Versicle" to "versicle", "Hymn" to "hymn", "Opening" to "opening", "Conclusion" to "conclusion",
        "Benediction" to "benediction", "Antiphon" to "antiphon", "Collect" to "collect", "Doxology" to "doxology",
        "Antiphon ad Benedictus" to "ad_benedictus", "Antiphon ad Magnificat" to "ad_magnificat",
        "Versicle & Response" to "versicle_response", "Blessing" to "blessing", "Supplication" to "supplication",
        "Invitatory Antiphon" to "invitatory", "Concluding Versicles" to "concluding_versicles",
    )
    // "Blessing before Léctio I" · "Marian Antiphon; Salve Regína" · "Short Reading (1 Peter 5:8-9)" · "Psalm 94; Venite"
    private val patterns = listOf(
        Regex("^Blessing before (.+)$") to "blessing_before",
        Regex("^Marian Antiphon; (.+)$") to "marian",
        Regex("^Short Reading \\((.+)\\)$") to "short_reading",
        Regex("^Psalm (\\d+); (.+)$") to "psalm",
    )

    /** [label] as the reader's vernacular names it; the label itself when there is no translation. */
    fun display(label: String?): String? {
        if (label == null) return null
        exact[label]?.let { return ContentStore.uiString("office.label.$it", label) }
        for ((re, key) in patterns) {
            val m = re.matchEntire(label) ?: continue
            var t = ContentStore.uiString("office.label.$key", "")
            if (t.isEmpty()) return label
            m.groupValues.drop(1).forEachIndexed { i, g -> t = t.replace("{$i}", g) }
            return t
        }
        return label
    }
}
