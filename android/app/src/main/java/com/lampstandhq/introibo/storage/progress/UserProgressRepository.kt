package com.lampstandhq.introibo.storage.progress

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * User progress repository — what the user has done across the app.
 * Ported from iOS Introibo/Storage/UserProgress.swift.
 *
 * All values live in DataStore Preferences so they survive app restarts
 * without requiring an account. Everything is local, matching the
 * "no accounts, no tracking" product principle.
 */

private val Context.progressDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "introibo_progress"
)

// ---------------------------------------------------------------------------
// Key constants (mirrors iOS ProgressKey)
// ---------------------------------------------------------------------------

private object ProgressKey {
    // Saints
    const val FOLLOWED_SAINT = "saints.followed"
    const val SAINT_STREAK = "saints.streak"         // prefix: saints.streak.<slug>
    const val SAINT_STREAK_LAST = "saints.streakLast" // prefix: saints.streakLast.<slug>
    const val SAINT_CHECKLIST = "saints.checklist"     // prefix: saints.checklist.<date>

    // Prayer Rule
    const val PRAYER_RULE = "prayers.rule"             // JSON-encoded PrayerRule
    const val PRAYER_CHECKLIST = "prayers.checklist"    // prefix: prayers.checklist.<date>
    const val ROSARY_LAST_DATE = "rosary.lastDate"     // ISO date of last completion
    const val ROSARY_LAST_SET = "rosary.lastSet"       // mystery set key

    // Schola
    const val LEARN_MASTERED = "learn.mastered"        // JSON-encoded List<String>
}

// ---------------------------------------------------------------------------
// PrayerRule data class
// ---------------------------------------------------------------------------

@Serializable
data class PrayerRule(
    val morning: List<String> = emptyList(),
    val midday: List<String> = emptyList(),
    val evening: List<String> = emptyList(),
) {
    val allSlugs: List<String> get() = morning + midday + evening
    val totalCount: Int get() = allSlugs.size
    val isEmpty: Boolean get() = morning.isEmpty() && midday.isEmpty() && evening.isEmpty()
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class UserProgressRepository(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }
    private val dayFormatter: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE

    // -----------------------------------------------------------------------
    // Followed saint
    // -----------------------------------------------------------------------

    private val followedSaintKey = stringPreferencesKey(ProgressKey.FOLLOWED_SAINT)

    val followedSaint: Flow<String?> = context.progressDataStore.data.map { prefs ->
        prefs[followedSaintKey]
    }

    suspend fun setFollowedSaint(slug: String?) {
        context.progressDataStore.edit { prefs ->
            if (slug != null) {
                prefs[followedSaintKey] = slug
            } else {
                prefs.remove(followedSaintKey)
            }
        }
        if (slug != null) {
            bumpSaintStreak(slug)
        }
    }

    // -----------------------------------------------------------------------
    // Saint streaks
    // -----------------------------------------------------------------------

    fun saintStreak(slug: String): Flow<Int> {
        val key = intPreferencesKey("${ProgressKey.SAINT_STREAK}.$slug")
        return context.progressDataStore.data.map { prefs -> prefs[key] ?: 0 }
    }

    /**
     * Bumps the streak for this saint if the last bump was yesterday
     * (continuation) or never (start). Same-day calls are idempotent;
     * calls after a skipped day reset the streak to 1.
     */
    suspend fun bumpSaintStreak(slug: String) {
        val today = LocalDate.now()
        val lastKey = stringPreferencesKey("${ProgressKey.SAINT_STREAK_LAST}.$slug")
        val streakKey = intPreferencesKey("${ProgressKey.SAINT_STREAK}.$slug")

        context.progressDataStore.edit { prefs ->
            val lastStr = prefs[lastKey]
            val current = prefs[streakKey] ?: 0

            if (lastStr != null) {
                val lastDay = LocalDate.parse(lastStr, dayFormatter)
                if (lastDay == today) {
                    return@edit // already bumped today
                }
                val daysBetween = ChronoUnit.DAYS.between(lastDay, today)
                prefs[streakKey] = if (daysBetween == 1L) current + 1 else 1
            } else {
                prefs[streakKey] = 1
            }
            prefs[lastKey] = today.format(dayFormatter)
        }
    }

    // -----------------------------------------------------------------------
    // Rosary
    // -----------------------------------------------------------------------

    private val rosaryLastDateKey = stringPreferencesKey(ProgressKey.ROSARY_LAST_DATE)
    private val rosaryLastSetKey = stringPreferencesKey(ProgressKey.ROSARY_LAST_SET)

    val rosaryLastDate: Flow<LocalDate?> = context.progressDataStore.data.map { prefs ->
        prefs[rosaryLastDateKey]?.let { LocalDate.parse(it, dayFormatter) }
    }

    val rosaryLastSet: Flow<String?> = context.progressDataStore.data.map { prefs ->
        prefs[rosaryLastSetKey]
    }

    suspend fun markRosaryPrayed(set: String, date: LocalDate = LocalDate.now()) {
        context.progressDataStore.edit { prefs ->
            prefs[rosaryLastDateKey] = date.format(dayFormatter)
            prefs[rosaryLastSetKey] = set
        }
    }

    // -----------------------------------------------------------------------
    // Schola — mastered lessons
    // -----------------------------------------------------------------------

    private val learnMasteredKey = stringPreferencesKey(ProgressKey.LEARN_MASTERED)

    val masteredLessons: Flow<Set<String>> = context.progressDataStore.data.map { prefs ->
        val raw = prefs[learnMasteredKey] ?: return@map emptySet()
        try {
            json.decodeFromString<List<String>>(raw).toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    suspend fun setMastered(slug: String, mastered: Boolean) {
        context.progressDataStore.edit { prefs ->
            val current = prefs[learnMasteredKey]?.let {
                try { json.decodeFromString<List<String>>(it).toMutableSet() }
                catch (_: Exception) { mutableSetOf() }
            } ?: mutableSetOf()

            if (mastered) current.add(slug) else current.remove(slug)
            prefs[learnMasteredKey] = json.encodeToString(current.sorted())
        }
    }

    // -----------------------------------------------------------------------
    // Prayer rule
    // -----------------------------------------------------------------------

    private val prayerRuleKey = stringPreferencesKey(ProgressKey.PRAYER_RULE)

    val prayerRule: Flow<PrayerRule> = context.progressDataStore.data.map { prefs ->
        val raw = prefs[prayerRuleKey] ?: return@map PrayerRule()
        try {
            json.decodeFromString<PrayerRule>(raw)
        } catch (_: Exception) {
            PrayerRule()
        }
    }

    suspend fun savePrayerRule(rule: PrayerRule) {
        context.progressDataStore.edit { prefs ->
            prefs[prayerRuleKey] = json.encodeToString(rule)
        }
    }

    suspend fun addToRule(slug: String, period: String) {
        val current = prayerRule.first()
        val updated = when (period) {
            "morning" -> if (slug !in current.morning) current.copy(morning = current.morning + slug) else current
            "midday" -> if (slug !in current.midday) current.copy(midday = current.midday + slug) else current
            "evening" -> if (slug !in current.evening) current.copy(evening = current.evening + slug) else current
            else -> current
        }
        savePrayerRule(updated)
    }

    suspend fun removeFromRule(slug: String) {
        val current = prayerRule.first()
        savePrayerRule(
            current.copy(
                morning = current.morning.filter { it != slug },
                midday = current.midday.filter { it != slug },
                evening = current.evening.filter { it != slug },
            )
        )
    }

    // -----------------------------------------------------------------------
    // Prayer checklist (daily completed prayers)
    // -----------------------------------------------------------------------

    private fun prayerChecklistKey(date: LocalDate = LocalDate.now()): Preferences.Key<String> =
        stringPreferencesKey("${ProgressKey.PRAYER_CHECKLIST}.${date.format(dayFormatter)}")

    fun completedPrayers(date: LocalDate = LocalDate.now()): Flow<Set<String>> {
        val key = prayerChecklistKey(date)
        return context.progressDataStore.data.map { prefs ->
            val raw = prefs[key] ?: return@map emptySet()
            try {
                json.decodeFromString<List<String>>(raw).toSet()
            } catch (_: Exception) {
                emptySet()
            }
        }
    }

    suspend fun togglePrayer(slug: String, date: LocalDate = LocalDate.now()) {
        val key = prayerChecklistKey(date)
        context.progressDataStore.edit { prefs ->
            val current = prefs[key]?.let {
                try { json.decodeFromString<List<String>>(it).toMutableSet() }
                catch (_: Exception) { mutableSetOf() }
            } ?: mutableSetOf()

            if (slug in current) current.remove(slug) else current.add(slug)
            prefs[key] = json.encodeToString(current.sorted())
        }
    }

    // -----------------------------------------------------------------------
    // Saint daily checklist (practices)
    // -----------------------------------------------------------------------

    private fun saintChecklistKey(date: LocalDate = LocalDate.now()): Preferences.Key<String> =
        stringPreferencesKey("${ProgressKey.SAINT_CHECKLIST}.${date.format(dayFormatter)}")

    fun completedPractices(date: LocalDate = LocalDate.now()): Flow<Set<String>> {
        val key = saintChecklistKey(date)
        return context.progressDataStore.data.map { prefs ->
            val raw = prefs[key] ?: return@map emptySet()
            try {
                json.decodeFromString<List<String>>(raw).toSet()
            } catch (_: Exception) {
                emptySet()
            }
        }
    }

    suspend fun togglePractice(id: String, date: LocalDate = LocalDate.now()) {
        val key = saintChecklistKey(date)
        context.progressDataStore.edit { prefs ->
            val current = prefs[key]?.let {
                try { json.decodeFromString<List<String>>(it).toMutableSet() }
                catch (_: Exception) { mutableSetOf() }
            } ?: mutableSetOf()

            if (id in current) current.remove(id) else current.add(id)
            prefs[key] = json.encodeToString(current.sorted())
        }
    }

    fun practiceCompleted(id: String, date: LocalDate = LocalDate.now()): Flow<Boolean> =
        completedPractices(date).map { id in it }

    fun dailyProgress(totalPractices: Int, date: LocalDate = LocalDate.now()): Flow<Double> =
        completedPractices(date).map { done ->
            if (totalPractices <= 0) 0.0 else done.size.toDouble() / totalPractices.toDouble()
        }

    // -----------------------------------------------------------------------
    // Reset all progress
    // -----------------------------------------------------------------------

    suspend fun resetAll(cancelNotifications: () -> Unit = {}) {
        cancelNotifications()
        context.progressDataStore.edit { prefs ->
            val keysToRemove = prefs.asMap().keys.filter { key ->
                val name = key.name
                name.startsWith("saints.") ||
                    name.startsWith("rosary.") ||
                    name.startsWith("learn.") ||
                    name.startsWith("prayers.")
            }
            keysToRemove.forEach { prefs.remove(it) }
        }
    }
}
