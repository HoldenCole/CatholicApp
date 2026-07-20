package com.lampstandhq.introibo.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color as AndroidColor
import android.widget.RemoteViews
import com.lampstandhq.introibo.R
import com.lampstandhq.introibo.app.MainActivity
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.widget.WidgetConfig
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

// MARK: - Day widgets (Today's Feast + Daily Reading, v1.2.3)
//
// Two further widget types alongside the prayer widget: the small "Today's
// Feast" card (the day of the liturgical calendar you are on) and the wide
// "Daily Reading" card (a quote from today's Mass propers, text chosen in the
// in-app widget settings). Unlike iOS — where the extension renders from an
// app-written snapshot — these share the app process, so they read
// ContentStore directly and are correct for any date the ordo covers.
//
// Both change content at local midnight only: one inexact alarm per provider,
// re-armed on every render, plus the time/timezone broadcasts.
//
// WELLBEING CUT LINE: content display only; no tracking of any kind.
//
// iOS mirror: LiturgicalDayWidget / DailyReadingWidget in IntroiboWidgets/.

private val dayFormatter = DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.US)

private fun liturgicalColorInt(key: String?): Int = when (key) {
    "violet" -> 0xFF6B369A.toInt()
    "rose" -> 0xFFA04860.toInt()
    "red" -> 0xFF8B1A1A.toInt()
    "green" -> 0xFF3B5C29.toInt()
    "black" -> 0xFF2A2521.toInt()
    else -> 0xFFC9A227.toInt()   // white feasts render as gold on parchment
}

private fun currentRite(context: Context): MissalRite = runBlocking {
    SettingsRepository(context.applicationContext).missalRite.first()
}

private fun prefersLatin(context: Context): Boolean = runBlocking {
    SettingsRepository(context.applicationContext).languageMode.first() == LanguageMode.LATIN_ONLY
}

private fun tapIntent(context: Context, target: String): PendingIntent {
    val tap = Intent(context, MainActivity::class.java).apply {
        action = MainActivity.ACTION_DEEPLINK
        putExtra(MainActivity.EXTRA_TARGET, target)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    return PendingIntent.getActivity(
        context,
        target.hashCode(),
        tap,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

/**
 * Shared plumbing for the two day-scoped providers: render every instance,
 * then arm one inexact alarm just after local midnight for the rollover.
 */
abstract class DayScopedWidgetProvider : AppWidgetProvider() {

    abstract val refreshAction: String
    abstract val alarmRequestCode: Int
    abstract fun buildViews(context: Context): RemoteViews

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
        scheduleMidnightUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            refreshAction -> refreshAll(context)
        }
    }

    override fun onDisabled(context: Context) {
        context.getSystemService(AlarmManager::class.java)
            ?.cancel(midnightPendingIntent(context))
        super.onDisabled(context)
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, javaClass))
        if (ids.isEmpty()) return
        for (id in ids) {
            manager.updateAppWidget(id, buildViews(context))
        }
        scheduleMidnightUpdate(context)
    }

    private fun scheduleMidnightUpdate(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java) ?: return
        val cal = java.util.Calendar.getInstance().apply {
            add(java.util.Calendar.DAY_OF_YEAR, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 1)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        val pi = midnightPendingIntent(context)
        alarm.cancel(pi)
        alarm.setWindow(AlarmManager.RTC, cal.timeInMillis, 10 * 60 * 1000L, pi)
    }

    private fun midnightPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, javaClass).apply { action = refreshAction }
        return PendingIntent.getBroadcast(
            context,
            alarmRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/** Small card: the day of the liturgical calendar you are on. */
class IntroiboDayWidgetProvider : DayScopedWidgetProvider() {

    override val refreshAction = "com.lampstandhq.introibo.widget.DAY_REFRESH"
    override val alarmRequestCode = 2

    override fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day)
        val today = LocalDate.now()
        val rite = currentRite(context)
        val latin = prefersLatin(context)

        val ordo = ContentStore.ordoForDate(today, rite)
        val ctx = LiturgicalContext.forDate(today, rite = rite)
        val latinName = ordo?.name ?: ctx.feriaLatin
        val english = ordo?.let { ContentStore.ordoNameEnglish(it.name) }

        views.setTextViewText(R.id.day_season, ctx.englishName.uppercase())
        views.setInt(R.id.day_color_pip, "setBackgroundColor", liturgicalColorInt(ordo?.color))
        views.setTextViewText(R.id.day_title, if (latin) latinName else (english ?: latinName))
        views.setTextViewText(R.id.day_date, today.format(dayFormatter))
        views.setOnClickPendingIntent(R.id.day_root, tapIntent(context, "widget:day"))
        return views
    }
}

/** Wide card: a quote from today's Mass propers. */
class IntroiboReadingWidgetProvider : DayScopedWidgetProvider() {

    override val refreshAction = "com.lampstandhq.introibo.widget.READING_REFRESH"
    override val alarmRequestCode = 3

    override fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_reading)
        val today = LocalDate.now()
        val rite = currentRite(context)
        val latin = prefersLatin(context)

        val ordo = ContentStore.ordoForDate(today, rite)
        val ctx = LiturgicalContext.forDate(today, rite = rite)
        val proper = ContentStore.properForDate(today, rite)
        val latinName = ordo?.name ?: ctx.feriaLatin
        val english = ordo?.let { ContentStore.ordoNameEnglish(it.name) }

        views.setInt(R.id.reading_color_pip, "setBackgroundColor", liturgicalColorInt(ordo?.color))
        views.setTextViewText(
            R.id.reading_feast,
            (if (latin) latinName else (english ?: latinName)).uppercase(),
        )

        val choice = WidgetConfig.readingText(context)
        val body: String
        val ref: String?
        val label: String
        if (proper != null) {
            when (choice) {
                "collect" -> { body = if (latin) proper.collect.lat else proper.collect.eng; ref = null; label = "Collect" }
                "epistle" -> { body = if (latin) proper.epistle.lat else proper.epistle.eng; ref = proper.epistle.ref; label = "Epistle" }
                "gospel" -> { body = if (latin) proper.gospel.lat else proper.gospel.eng; ref = proper.gospel.ref; label = "Gospel" }
                else -> { body = if (latin) proper.introit.lat else proper.introit.eng; ref = proper.introit.ref; label = "Introit" }
            }
        } else {
            body = context.getString(R.string.widget_tap_to_pray)
            ref = null
            label = "Missa"
        }
        views.setTextViewText(R.id.reading_label, label)
        views.setTextViewText(R.id.reading_ref, ref ?: "")
        views.setTextViewText(R.id.reading_body, body)
        views.setOnClickPendingIntent(R.id.reading_root, tapIntent(context, "widget:reading"))
        return views
    }
}
