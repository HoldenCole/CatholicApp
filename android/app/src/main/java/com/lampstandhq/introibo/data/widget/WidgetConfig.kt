package com.lampstandhq.introibo.data.widget

import android.content.Context
import android.content.SharedPreferences

// MARK: - WidgetConfig
//
// The home-screen widget's small persistent configuration, deliberately
// independent of the Prayer Rule data model (the Rule is being reworked; the
// widget must not couple to it). Stored in its own SharedPreferences file so
// it survives app restart and upgrade-over-install like any other setting.
//
// The mode set is EXTENSIBLE (string keys, exhaustive `when` at render sites)
// so the planned "Follow my Life Rule" mode can be added later additively.
//
// WELLBEING CUT LINE: this config carries what the widget SHOWS, never any
// completion/progress/streak state. Do not add tracking fields of any kind.
//
// iOS mirror: Introibo/Widget/WidgetConfigStore.swift (App Group defaults).

/** Widget display mode. Extensible set — do not collapse to a Boolean. */
enum class WidgetMode(val key: String) {
    OFFICE("office"),   // current canonical hour, from OfficeSchedule
    PRAYER("prayer");   // user-chosen prayer per time slot

    companion object {
        fun fromKey(key: String?): WidgetMode =
            entries.firstOrNull { it.key == key } ?: OFFICE
    }
}

/** The three chosen-prayer time slots. */
enum class WidgetSlot(val key: String, val label: String) {
    MORNING("morning", "Morning"),
    MIDDAY("midday", "Midday"),
    EVENING("evening", "Evening");
}

object WidgetConfig {

    private const val PREFS = "introibo_widget"
    private const val KEY_MODE = "mode"

    // Slot boundaries as minutes since midnight. Defaults align with the
    // Office's own sense of the day: Laudes in the early morning, Sext at
    // midday, Vespers in the evening.
    const val DEFAULT_MORNING_START = 4 * 60       // 04:00
    const val DEFAULT_MIDDAY_START = 12 * 60       // 12:00
    const val DEFAULT_EVENING_START = 17 * 60      // 17:00

    // Default slot prayers: Morning Offering / Angelus / Act of Contrition.
    // Chosen so the widget renders something prayable before any configuration.
    private val DEFAULT_SLOT_PRAYERS = mapOf(
        WidgetSlot.MORNING to "morning",
        WidgetSlot.MIDDAY to "angelus",
        WidgetSlot.EVENING to "actusContr",
    )

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun mode(context: Context): WidgetMode =
        WidgetMode.fromKey(prefs(context).getString(KEY_MODE, null))

    fun setMode(context: Context, mode: WidgetMode) {
        prefs(context).edit().putString(KEY_MODE, mode.key).apply()
    }

    /** The prayer slug assigned to [slot] (falls back to a sensible default). */
    fun slotPrayer(context: Context, slot: WidgetSlot): String =
        prefs(context).getString("slot.${slot.key}", null)
            ?: DEFAULT_SLOT_PRAYERS.getValue(slot)

    fun setSlotPrayer(context: Context, slot: WidgetSlot, slug: String) {
        prefs(context).edit().putString("slot.${slot.key}", slug).apply()
    }

    /** Start of [slot] in minutes since midnight. */
    fun slotStart(context: Context, slot: WidgetSlot): Int =
        prefs(context).getInt(
            "start.${slot.key}",
            when (slot) {
                WidgetSlot.MORNING -> DEFAULT_MORNING_START
                WidgetSlot.MIDDAY -> DEFAULT_MIDDAY_START
                WidgetSlot.EVENING -> DEFAULT_EVENING_START
            },
        )

    fun setSlotStart(context: Context, slot: WidgetSlot, minutes: Int) {
        prefs(context).edit().putInt("start.${slot.key}", minutes).apply()
    }

    /**
     * The slot in effect at [nowMinutes] (minutes since midnight): the slot
     * whose start is at or before now; before the morning start, the previous
     * evening's slot is still in effect (mirrors OfficeSchedule's roll-back).
     */
    fun currentSlot(context: Context, nowMinutes: Int): WidgetSlot {
        val starts = WidgetSlot.entries.map { it to slotStart(context, it) }
        return starts.filter { it.second <= nowMinutes }.maxByOrNull { it.second }?.first
            ?: WidgetSlot.EVENING
    }

    /**
     * Minutes-since-midnight of the next slot boundary strictly after
     * [nowMinutes], or null if the next boundary is tomorrow's first one.
     * Used to schedule the widget's next refresh.
     */
    fun nextSlotBoundary(context: Context, nowMinutes: Int): Int? =
        WidgetSlot.entries.map { slotStart(context, it) }
            .filter { it > nowMinutes }
            .minOrNull()
}
