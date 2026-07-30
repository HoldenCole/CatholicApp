package com.lampstandhq.introibo.storage.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * DataStore-backed settings repository.
 * Ported from iOS Introibo/Storage/Settings.swift.
 *
 * Exposes each setting as a [Flow] for reactive observation in Compose
 * and provides suspend functions to mutate values.
 */

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "introibo_settings"
)

class SettingsRepository(private val context: Context) {

    // -----------------------------------------------------------------------
    // Preferences keys
    // -----------------------------------------------------------------------

    private object PrefsKeys {
        val RITE = stringPreferencesKey(SettingsKey.RITE)
        val PENANCE = stringPreferencesKey(SettingsKey.PENANCE)
        val DARK_MODE = booleanPreferencesKey(SettingsKey.DARK_MODE)
        val THEME = stringPreferencesKey(SettingsKey.THEME)
        val LANGUAGE = stringPreferencesKey(SettingsKey.LANGUAGE)
        val FONT_SIZE = floatPreferencesKey(SettingsKey.FONT_SIZE)
        val FONT_RANGE = stringPreferencesKey(SettingsKey.FONT_RANGE)
        val TEXT_DARKNESS = floatPreferencesKey(SettingsKey.TEXT_DARKNESS)
        val SHOW_LEONINE_PRAYERS = booleanPreferencesKey(SettingsKey.SHOW_LEONINE_PRAYERS)
        val SHOW_UPCOMING_FEASTS = booleanPreferencesKey(SettingsKey.SHOW_UPCOMING_FEASTS)
    }

    // -----------------------------------------------------------------------
    // Flows — observe settings reactively
    // -----------------------------------------------------------------------

    val missalRite: Flow<MissalRite> = context.settingsDataStore.data.map { prefs ->
        MissalRite.fromRaw(prefs[PrefsKeys.RITE])
    }

    val penanceDiscipline: Flow<PenanceDiscipline> = context.settingsDataStore.data.map { prefs ->
        PenanceDiscipline.fromRaw(prefs[PrefsKeys.PENANCE])
    }

    val appTheme: Flow<AppTheme> = context.settingsDataStore.data.map { prefs ->
        // Legacy dark mode key fallback, matching iOS behaviour.
        val legacy = prefs[PrefsKeys.DARK_MODE] ?: false
        val raw = prefs[PrefsKeys.THEME] ?: if (legacy) "dark" else null
        AppTheme.fromRaw(raw)
    }

    val languageMode: Flow<LanguageMode> = context.settingsDataStore.data.map { prefs ->
        LanguageMode.fromRaw(prefs[PrefsKeys.LANGUAGE])
    }

    val fontScale: Flow<Float> = context.settingsDataStore.data.map { prefs ->
        val value = prefs[PrefsKeys.FONT_SIZE] ?: FontSizeScale.DEFAULT_VALUE
        FontSizeScale.coerce(value)
    }

    val fontRange: Flow<FontRange> = context.settingsDataStore.data.map { prefs ->
        FontRange.fromRaw(prefs[PrefsKeys.FONT_RANGE])
    }

    val textDarkness: Flow<Float> = context.settingsDataStore.data.map { prefs ->
        prefs[PrefsKeys.TEXT_DARKNESS] ?: 1.0f
    }

    val showLeoninePrayers: Flow<Boolean> = context.settingsDataStore.data.map { prefs ->
        prefs[PrefsKeys.SHOW_LEONINE_PRAYERS] ?: true
    }

    /** The Upcoming Feasts card on the Home (Hodie) screen. Off by default. */
    val showUpcomingFeasts: Flow<Boolean> = context.settingsDataStore.data.map { prefs ->
        prefs[PrefsKeys.SHOW_UPCOMING_FEASTS] ?: false
    }

    // -----------------------------------------------------------------------
    // Mutations
    // -----------------------------------------------------------------------

    suspend fun setMissalRite(rite: MissalRite) {
        context.settingsDataStore.edit { it[PrefsKeys.RITE] = rite.rawValue }
    }

    suspend fun setPenanceDiscipline(discipline: PenanceDiscipline) {
        context.settingsDataStore.edit { it[PrefsKeys.PENANCE] = discipline.rawValue }
    }

    suspend fun setAppTheme(theme: AppTheme) {
        context.settingsDataStore.edit { it[PrefsKeys.THEME] = theme.rawValue }
    }

    suspend fun setLanguageMode(mode: LanguageMode) {
        context.settingsDataStore.edit { it[PrefsKeys.LANGUAGE] = mode.rawValue }
    }

    suspend fun setFontScale(scale: Float) {
        context.settingsDataStore.edit { it[PrefsKeys.FONT_SIZE] = FontSizeScale.coerce(scale) }
    }

    suspend fun setFontRange(range: FontRange) {
        context.settingsDataStore.edit { it[PrefsKeys.FONT_RANGE] = range.rawValue }
    }

    suspend fun setTextDarkness(value: Float) {
        context.settingsDataStore.edit { it[PrefsKeys.TEXT_DARKNESS] = value.coerceIn(0f, 1f) }
    }

    suspend fun setShowLeoninePrayers(show: Boolean) {
        context.settingsDataStore.edit { it[PrefsKeys.SHOW_LEONINE_PRAYERS] = show }
    }

    suspend fun setShowUpcomingFeasts(show: Boolean) {
        context.settingsDataStore.edit { it[PrefsKeys.SHOW_UPCOMING_FEASTS] = show }
    }
}
