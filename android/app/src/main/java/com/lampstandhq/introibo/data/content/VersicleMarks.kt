package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour

/**
 * The ℣./℟. marks of the template's versicle parts, added at render time:
 * the templates carry "Dómine, exáudi oratiónem meam." / "Et clamor meus ad
 * te véniat." without marks while the parts the rubrics assemble from Divinum
 * Officium carry them, so the hours showed both forms. The labels say which
 * part is a versicle, a blessing ("Benedíctio.") or the absolution; the marks
 * are language-neutral and the Latin labels stay Latin in every vernacular.
 * Swift mirror: Introibo/Data/VersicleMarks.swift
 */
object VersicleMarks {
    private val MARKED = Regex("^(℣\\.|℟\\.|℟\\.br\\.|V\\.|R\\.|Ant\\.|Benedíctio\\.|Benedictio\\.|Absolútio\\.|Absolutio\\.)")
    private val VERSICLE_LABELS = setOf(
        "Versicle", "Versus", "Versiculus", "Versicle & Response", "Opening", "Supplication", "Tu autem",
        "Conclusio", "Conclusio (continued)", "Benediction", "Versicle after Nocturn I", "Versicle after Nocturn II", "Versicle after Nocturn III",
    )

    class Marked(val lat: String?, val eng: String?, val latR: String?, val engR: String?)

    private fun prefix(t: String?, mark: String): String? {
        if (t.isNullOrBlank() || MARKED.containsMatchIn(t.trimStart())) return t
        return "$mark $t"
    }

    /** The response of a short reading: "Tu autem, Dómine... Deo grátias." as ℣./℟. lines. */
    private fun tuAutem(t: String?): String? {
        if (t == null) return null
        val i = t.indexOf(" Deo grátias"); val j = t.indexOf(" Thanks be to God"); val k = t.indexOf(" Demos gracias")
        val cut = listOf(i, j, k).filter { it > 0 }.minOrNull() ?: return prefix(t, "℣.")
        return "℣. " + t.substring(0, cut).trim() + "\n℟. " + t.substring(cut).trim()
    }

    fun of(p: Hour.Part): Marked {
        if (p.type != "vr") return Marked(p.lat, p.eng, p.latR, p.engR)
        val label = p.label ?: ""
        return when {
            label == "Absolutio" -> Marked(prefix(p.lat, "Absolútio."), prefix(p.eng, "Absolútio."), prefix(p.latR, "℟."), prefix(p.engR, "℟."))
            label.startsWith("Blessing before") -> Marked(prefix(p.lat, "Benedíctio."), prefix(p.eng, "Benedíctio."), prefix(p.latR, "℟."), prefix(p.engR, "℟."))
            label == "Blessing" -> Marked(prefix(p.lat, "℣."), prefix(p.eng, "℣."), prefix(p.latR, "Benedíctio."), prefix(p.engR, "Benedíctio."))
            label.startsWith("Short Reading") -> Marked(p.lat, p.eng, tuAutem(p.latR), tuAutem(p.engR))
            label in VERSICLE_LABELS -> Marked(prefix(p.lat, "℣."), prefix(p.eng, "℣."), prefix(p.latR, "℟."), prefix(p.engR, "℟."))
            else -> Marked(p.lat, p.eng, p.latR, p.engR)
        }
    }
}
