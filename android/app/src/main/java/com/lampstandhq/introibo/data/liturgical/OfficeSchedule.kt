package com.lampstandhq.introibo.data.liturgical

import com.lampstandhq.introibo.data.model.Hour
import java.util.Calendar

// MARK: - OfficeSchedule
//
// The single source of truth for "which canonical hour is in effect right now".
// Extracted from OfficeScreen so the Office tab AND the home-screen widget (and
// any future caller) select the current hour identically. Pure given its
// inputs — safe to call from a widget / background context.
//
// iOS mirror: Introibo/Liturgical/OfficeSchedule.swift

object OfficeSchedule {

    /**
     * The canonical hour in effect at [nowMinutes] (minutes since midnight):
     * the nearest hour whose scheduled time is at or before now. Before the
     * first hour of the day (Matutinum at midnight) there is no preceding hour
     * today, so we roll back to the previous day's Completorium ("completorium"),
     * matching the Office tab's behaviour.
     */
    fun currentHourSlug(hours: List<Hour>, nowMinutes: Int = currentMinuteOfDay()): String {
        var best: Pair<String, Int>? = null
        for (hour in hours) {
            val diff = nowMinutes - (hour.hour * 60 + hour.minute)
            if (diff >= 0 && (best == null || diff < best.second)) {
                best = hour.slug to diff
            }
        }
        return best?.first ?: "completorium"
    }

    /** Minutes since midnight for the device's current local time. */
    fun currentMinuteOfDay(): Int {
        val cal = Calendar.getInstance()
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }
}
