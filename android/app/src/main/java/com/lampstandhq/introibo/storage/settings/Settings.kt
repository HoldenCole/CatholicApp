package com.lampstandhq.introibo.storage.settings

import com.lampstandhq.introibo.data.content.ContentStore

/**
 * User-facing settings enums and key constants.
 * Ported from iOS Introibo/Storage/Settings.swift.
 *
 * All keys live under the "settings.*" prefix to match the iOS
 * UserDefaults layout.
 */

// ---------------------------------------------------------------------------
// Missal rite
// ---------------------------------------------------------------------------

enum class MissalRite(val rawValue: String, private val labelEN: String, val short: String) {
    RITE_1962("1962", "1962 Missal (Roncalli)", "Missále Romanum 1962"),
    RITE_1955("1955", "1955 Holy Week reforms", "Missále Romanum 1955"),
    PRE_1955("pre1955", "Pre-1955 rubrics", "Missále Romanum pre-1955");

    /** Vernacular display label. */
    val label: String get() = ContentStore.uiString("settings.rite.$rawValue", labelEN)

    companion object {
        fun fromRaw(raw: String?): MissalRite =
            entries.firstOrNull { it.rawValue == raw } ?: RITE_1962
    }
}

// ---------------------------------------------------------------------------
// Penance discipline
// ---------------------------------------------------------------------------

enum class PenanceDiscipline(val rawValue: String, private val labelEN: String, val short: String) {
    DISCIPLINE_1962("1962", "1962 discipline", "Codex 1962"),
    DISCIPLINE_1917("1917", "1917 Code", "Codex 1917"),
    STRICT("strict", "Stricter (pre-Pius XII)", "Discipline stricta");

    /** Vernacular display label. */
    val label: String get() = ContentStore.uiString("settings.penance.$rawValue", labelEN)

    companion object {
        fun fromRaw(raw: String?): PenanceDiscipline =
            entries.firstOrNull { it.rawValue == raw } ?: DISCIPLINE_1962
    }
}

// ---------------------------------------------------------------------------
// Font range
// ---------------------------------------------------------------------------

enum class FontRange(
    val rawValue: String,
    private val labelEN: String,
    val min: Float,
    val max: Float,
    val defaultVal: Float,
) {
    SMALLER("smaller", "Smaller", 0.7f, 1.1f, 0.85f),
    NORMAL("normal", "Normal", 1.0f, 1.5f, 1.15f),
    BIGGER("bigger", "Bigger", 1.3f, 2.0f, 1.5f);

    /** Vernacular display label. */
    val label: String get() = ContentStore.uiString("settings.font.$rawValue", labelEN)

    companion object {
        fun fromRaw(raw: String?): FontRange =
            entries.firstOrNull { it.rawValue == raw } ?: NORMAL
    }
}

// ---------------------------------------------------------------------------
// Font size scale constants
// ---------------------------------------------------------------------------

object FontSizeScale {
    const val MIN: Float = 0.7f
    const val MAX: Float = 2.0f
    const val DEFAULT_VALUE: Float = 1.15f

    fun coerce(value: Float): Float =
        if (value < MIN || value > MAX) DEFAULT_VALUE else value
}

// ---------------------------------------------------------------------------
// Language mode
// ---------------------------------------------------------------------------

enum class LanguageMode(val rawValue: String) {
    BOTH("both"),
    LATIN_ONLY("latin"),
    VERNACULAR("vernacular");

    /** Display label; the vernacular rows name the chosen vernacular. */
    fun label(vernacular: VernacularLanguage = VernacularLanguage.ENGLISH): String = when (this) {
        BOTH -> ContentStore.uiString("settings.language.both", "Latin & {0}").replace("{0}", vernacular.displayName)
        LATIN_ONLY -> ContentStore.uiString("settings.language.latin", "Latin Only")
        VERNACULAR -> ContentStore.uiString("settings.language.vernacular", "{0} Only").replace("{0}", vernacular.displayName)
    }

    companion object {
        fun fromRaw(raw: String?): LanguageMode =
            entries.firstOrNull { it.rawValue == raw } ?: BOTH
    }
}

// ---------------------------------------------------------------------------
// Vernacular language
// ---------------------------------------------------------------------------

/**
 * Which vernacular the eng-side of every bilingual surface shows. Spanish
 * coverage is the *_es.json overlay (prayers, Marian antiphons, hour
 * metadata); anything not covered falls back to English.
 */
enum class VernacularLanguage(val rawValue: String, val displayName: String) {
    ENGLISH("en", "English"),
    SPANISH("es", "Español");

    companion object {
        fun fromRaw(raw: String?): VernacularLanguage =
            entries.firstOrNull { it.rawValue == raw } ?: ENGLISH
    }
}

// ---------------------------------------------------------------------------
// App theme
// ---------------------------------------------------------------------------

enum class AppTheme(val rawValue: String, private val labelEN: String, val latin: String) {
    PARCHMENT("parchment", "Parchment", "Membrana"),
    WHITE("white", "Clean White", "Candida"),
    DARK("dark", "Dark (Walnut)", "Obscura");

    /** Vernacular display label. */
    val label: String get() = ContentStore.uiString("settings.theme.$rawValue", labelEN)

    companion object {
        fun fromRaw(raw: String?): AppTheme =
            entries.firstOrNull { it.rawValue == raw } ?: PARCHMENT
    }
}

// ---------------------------------------------------------------------------
// Settings keys — typed constants so views can't misspell them
// ---------------------------------------------------------------------------

object SettingsKey {
    const val RITE = "settings.rite"
    const val PENANCE = "settings.penance"
    const val DARK_MODE = "settings.darkMode"
    const val THEME = "settings.theme"
    const val LANGUAGE = "settings.language"
    const val FONT_SIZE = "settings.fontSize"
    const val FONT_RANGE = "settings.fontRange"
    const val TEXT_DARKNESS = "settings.textDarkness"
    const val SHOW_LEONINE_PRAYERS = "settings.showLeoninePrayers"
    const val SHOW_UPCOMING_FEASTS = "settings.showUpcomingFeasts"
    /** Read the Martyrology in the second part of Prime (on by default). */
    const val PRIME_MARTYROLOGY = "settings.primeMartyrology"
    const val VERNACULAR_LANG = "settings.vernacularLang"
}
