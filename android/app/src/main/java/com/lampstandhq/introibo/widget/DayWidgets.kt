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
import com.lampstandhq.introibo.data.liturgical.LiturgicalYear
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
        views.setInt(R.id.day_ribbon, "setBackgroundColor", liturgicalColorInt(ordo?.color))
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

        views.setInt(R.id.reading_ribbon, "setBackgroundColor", liturgicalColorInt(ordo?.color))
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
                "collect" -> { body = if (latin) proper.collect.lat else proper.collect.eng; ref = null; label = ContentStore.uiString("widget.reading.collect", "Collect") }
                "epistle" -> { body = if (latin) proper.epistle.lat else proper.epistle.eng; ref = proper.epistle.ref; label = ContentStore.uiString("widget.reading.epistle", "Epistle") }
                "gospel" -> { body = if (latin) proper.gospel.lat else proper.gospel.eng; ref = proper.gospel.ref; label = ContentStore.uiString("widget.reading.gospel", "Gospel") }
                else -> { body = if (latin) proper.introit.lat else proper.introit.eng; ref = proper.introit.ref; label = ContentStore.uiString("widget.reading.introit", "Introit") }
            }
        } else {
            body = ContentStore.uiString("widget.tap_to_pray", context.getString(R.string.widget_tap_to_pray))
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

/**
 * Tall card: today's feast, your place in the season, and the saints ahead.
 * The "season progress" bar is the CHURCH'S calendar — day N of M in the
 * current season run — never the user's behaviour (wellbeing CUT LINE).
 */
class IntroiboSaintsWidgetProvider : DayScopedWidgetProvider() {

    override val refreshAction = "com.lampstandhq.introibo.widget.SAINTS_REFRESH"
    override val alarmRequestCode = 4

    private val upcomingDateFormatter = DateTimeFormatter.ofPattern("d MMM", Locale.US)

    override fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_saints)
        val today = LocalDate.now()
        val rite = currentRite(context)
        val latin = prefersLatin(context)

        val ordo = ContentStore.ordoForDate(today, rite)
        val ctx = LiturgicalContext.forDate(today, rite = rite)
        val latinName = ordo?.name ?: ctx.feriaLatin
        val english = ordo?.let { ContentStore.ordoNameEnglish(it.name) }

        views.setTextViewText(R.id.saints_season, ctx.englishName.uppercase())
        views.setInt(R.id.saints_ribbon, "setBackgroundColor", liturgicalColorInt(ordo?.color))
        views.setTextViewText(R.id.saints_title, if (latin) latinName else (english ?: latinName))

        val segment = LiturgicalYear.seasons(today.year, rite)
            .firstOrNull { !today.isBefore(it.startDate) && !today.isAfter(it.endDate) }
        if (segment != null) {
            val day = java.time.temporal.ChronoUnit.DAYS
                .between(segment.startDate, today).toInt() + 1
            views.setProgressBar(R.id.saints_progress, segment.dayCount, day, false)
            views.setTextViewText(R.id.saints_progress_text, "Day $day of ${segment.dayCount}")
        } else {
            views.setProgressBar(R.id.saints_progress, 1, 0, false)
            views.setTextViewText(R.id.saints_progress_text, "")
        }

        // Upcoming saints (or all notable days), straight from the ordo.
        val saintsOnly = WidgetConfig.saintsFilter(context) != "all"
        val ahead = LiturgicalYear.upcoming(start = today, window = 30, rite = rite)
            .filter { !saintsOnly || it.ordo?.winner == "sanctoral" }
            .take(upcomingRows.size)
        upcomingRows.forEachIndexed { i, (rowId, nameId, dateId) ->
            val day = ahead.getOrNull(i)
            val dayOrdo = day?.ordo
            if (day == null || dayOrdo == null) {
                views.setViewVisibility(rowId, android.view.View.GONE)
            } else {
                views.setViewVisibility(rowId, android.view.View.VISIBLE)
                views.setTextViewText(
                    nameId,
                    if (latin) dayOrdo.name else (day.englishName ?: dayOrdo.name),
                )
                views.setTextViewText(dateId, day.date.format(upcomingDateFormatter))
            }
        }

        views.setOnClickPendingIntent(R.id.saints_root, tapIntent(context, "widget:day"))
        return views
    }

    private val upcomingRows = listOf(
        Triple(R.id.saints_up1, R.id.saints_up1_name, R.id.saints_up1_date),
        Triple(R.id.saints_up2, R.id.saints_up2_name, R.id.saints_up2_date),
        Triple(R.id.saints_up3, R.id.saints_up3_name, R.id.saints_up3_date),
        Triple(R.id.saints_up4, R.id.saints_up4_name, R.id.saints_up4_date),
    )
}
