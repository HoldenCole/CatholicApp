package com.lampstandhq.introibo.data.penance

import com.lampstandhq.introibo.data.content.ContentStore

import android.content.Context
import android.content.SharedPreferences
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Traditional optional penances the user can select.
 * Port of iOS Introibo/Data/OptionalPenance.swift.
 */
data class OptionalPenance(
    val id: String,
    val title: String,
    val latin: String,
    val desc: String,
)

object OptionalPenances {

    /** Computed so the vernacular overlay applies to the titles and descriptions. */
    val all: List<OptionalPenance> get() = listOf(
        OptionalPenance(
            id = "fast_bread_water",
            title = ContentStore.uiString("penance.fast_bread_water.title", "Bread and Water Fast"),
            latin = "Ieiúnium in pane et aqua",
            desc = ContentStore.uiString("penance.fast_bread_water.desc", "Take only bread and water for one or more meals today."),
        ),
        OptionalPenance(
            id = "no_meat",
            title = ContentStore.uiString("penance.no_meat.title", "Voluntary Abstinence"),
            latin = "Abstinéntia voluntária",
            desc = ContentStore.uiString("penance.no_meat.desc", "Abstain from the flesh of warm-blooded animals, even when not required."),
        ),
        OptionalPenance(
            id = "no_sweets",
            title = ContentStore.uiString("penance.no_sweets.title", "Abstain from Sweets"),
            latin = "Sine dulcibus",
            desc = ContentStore.uiString("penance.no_sweets.desc", "Deny yourself desserts, candy, or sweetened drinks today."),
        ),
        OptionalPenance(
            id = "no_entertainment",
            title = ContentStore.uiString("penance.no_entertainment.title", "Media Fast"),
            latin = "Ieiúnium a spectáculis",
            desc = ContentStore.uiString("penance.no_entertainment.desc", "No social media, television, music, or recreational internet today."),
        ),
        OptionalPenance(
            id = "cold_shower",
            title = ContentStore.uiString("penance.cold_shower.title", "Cold Water Mortification"),
            latin = "Mortificátio córporis",
            desc = ContentStore.uiString("penance.cold_shower.desc", "Take a cold shower or deny yourself hot water as a bodily penance."),
        ),
        OptionalPenance(
            id = "extra_prayers",
            title = ContentStore.uiString("penance.extra_prayers.title", "Additional Prayers"),
            latin = "Oratiónes addítæ",
            desc = ContentStore.uiString("penance.extra_prayers.desc", "Add an extra Rosary decade, chaplet, or 15 minutes of mental prayer."),
        ),
        OptionalPenance(
            id = "almsgiving",
            title = ContentStore.uiString("penance.almsgiving.title", "Almsgiving"),
            latin = "Eleemósyna",
            desc = ContentStore.uiString("penance.almsgiving.desc", "Give to the poor or to a charitable cause today, beyond your usual giving."),
        ),
        OptionalPenance(
            id = "silence",
            title = ContentStore.uiString("penance.silence.title", "Partial Silence"),
            latin = "Siléntium partiále",
            desc = ContentStore.uiString("penance.silence.desc", "Observe silence for a portion of the day, speaking only when necessary."),
        ),
    )

    private const val PREFS_NAME = "introibo_penance"
    private const val KEY = "penance.selected"
    private val json = Json { ignoreUnknownKeys = true }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun selectedIDs(context: Context): Set<String> {
        val raw = prefs(context).getString(KEY, null) ?: return emptySet()
        return try {
            json.decodeFromString<List<String>>(raw).toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    fun setSelected(context: Context, id: String, selected: Boolean) {
        val current = selectedIDs(context).toMutableSet()
        if (selected) current.add(id) else current.remove(id)
        prefs(context).edit()
            .putString(KEY, json.encodeToString(current.sorted()))
            .apply()
    }

    fun selected(context: Context): List<OptionalPenance> {
        val ids = selectedIDs(context)
        return all.filter { it.id in ids }
    }
}
