package com.lampstandhq.introibo.ui.today

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.isEmberDay
import com.lampstandhq.introibo.data.liturgical.isFirstFriday
import com.lampstandhq.introibo.data.liturgical.isFirstSaturday
import com.lampstandhq.introibo.data.liturgical.seasonalNote
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.storage.progress.PrayerRule
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.PenanceDiscipline
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Calendar

/**
 * ViewModel for the Today (Hodie) screen.
 * Holds liturgical context and user progress state.
 */
class TodayViewModel(application: Application) : AndroidViewModel(application) {

    private val settingsRepo = SettingsRepository(application)
    val progressRepo = UserProgressRepository(application)

    /** Current liturgical context. */
    private val _ctx = MutableStateFlow(LiturgicalContext.current())
    val ctx: StateFlow<LiturgicalContext> = _ctx.asStateFlow()

    val rite = settingsRepo.missalRite.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), MissalRite.RITE_1962
    )

    val discipline = settingsRepo.penanceDiscipline.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), PenanceDiscipline.DISCIPLINE_1962
    )

    val prayerRule = progressRepo.prayerRule.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), PrayerRule()
    )

    val completedPrayers = progressRepo.completedPrayers().stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), emptySet()
    )

    val masteredLessons = progressRepo.masteredLessons.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), emptySet()
    )

    val followedSaint = progressRepo.followedSaint.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), null
    )

    val rosaryLastDate = progressRepo.rosaryLastDate.stateIn(
        viewModelScope, SharingStarted.WhileSubscribed(5_000), null
    )

    // ---- Derived values ----

    fun todayProper(): MassProper? {
        val slug = ctx.value.properSlug ?: return null
        return ContentStore.proper(slug)
    }

    fun seasonalNote(): String? = ctx.value.seasonalNote

    fun isFirstFriday(): Boolean = ctx.value.isFirstFriday
    fun isFirstSaturday(): Boolean = ctx.value.isFirstSaturday
    fun isEmberDay(): Boolean = ctx.value.isEmberDay

    /** Returns the right offering slug based on time of day. */
    fun offeringSlug(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> "morning"
            hour < 18 -> "salve"
            else      -> "suscipe"
        }
    }

    fun offeringTitle(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> "Morning Offering"
            hour < 18 -> "Afternoon Prayer"
            else      -> "Night Prayer"
        }
    }

    fun offeringLatin(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> "Oblatio Matutina"
            hour < 18 -> "Salve Regina"
            else      -> "Suscipe, Domine"
        }
    }

    fun formatDate(date: LocalDate): String {
        return date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
    }
}
