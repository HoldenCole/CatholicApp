package com.lampstandhq.introibo.storage.notification

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Notification schedule model and DataStore-backed store.
 * Ported from iOS Introibo/Storage/NotificationSchedule.swift.
 */

private val Context.notificationDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "introibo_notifications"
)

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

@Serializable
data class NotificationSchedule(
    val id: String,
    val days: Set<Int>,
    val hour: Int,
    val minute: Int,
    val isEnabled: Boolean,
)

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class NotificationStore(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }
    private val schedulesKey = stringPreferencesKey("notifications.schedules")

    // -----------------------------------------------------------------------
    // Read
    // -----------------------------------------------------------------------

    val allSchedules: Flow<List<NotificationSchedule>> =
        context.notificationDataStore.data.map { prefs ->
            val raw = prefs[schedulesKey] ?: return@map emptyList()
            try {
                json.decodeFromString<List<NotificationSchedule>>(raw)
            } catch (_: Exception) {
                emptyList()
            }
        }

    suspend fun all(): List<NotificationSchedule> = allSchedules.first()

    suspend fun schedule(id: String): NotificationSchedule? =
        all().firstOrNull { it.id == id }

    // -----------------------------------------------------------------------
    // Write
    // -----------------------------------------------------------------------

    suspend fun upsert(schedule: NotificationSchedule) {
        context.notificationDataStore.edit { prefs ->
            val current = currentList(prefs).toMutableList()
            val idx = current.indexOfFirst { it.id == schedule.id }
            if (idx >= 0) {
                current[idx] = schedule
            } else {
                current.add(schedule)
            }
            prefs[schedulesKey] = json.encodeToString(current)
        }
    }

    suspend fun remove(id: String) {
        context.notificationDataStore.edit { prefs ->
            val current = currentList(prefs).filter { it.id != id }
            prefs[schedulesKey] = json.encodeToString(current)
        }
    }

    suspend fun removeAll() {
        context.notificationDataStore.edit { prefs ->
            prefs.remove(schedulesKey)
        }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    private fun currentList(prefs: Preferences): List<NotificationSchedule> {
        val raw = prefs[schedulesKey] ?: return emptyList()
        return try {
            json.decodeFromString<List<NotificationSchedule>>(raw)
        } catch (_: Exception) {
            emptyList()
        }
    }
}
