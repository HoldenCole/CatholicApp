package com.lampstandhq.introibo.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.lampstandhq.introibo.R
import com.lampstandhq.introibo.app.MainActivity
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.OfficeSchedule
import com.lampstandhq.introibo.data.widget.WidgetConfig
import com.lampstandhq.introibo.data.widget.WidgetMode
import com.lampstandhq.introibo.data.widget.WidgetSlot

// MARK: - IntroiboWidgetProvider
//
// The home-screen widget: an INVITATION to pray, never a tracker. It shows
// the right prayer content for the current part of the day and opens directly
// into it, ready to pray. Content is computed from config + clock + the SAME
// OfficeSchedule logic the Office tab uses, so widget and app can never
// disagree about the current hour.
//
// WELLBEING CUT LINE (non-negotiable): no completion state, counts, streaks,
// progress, history, or missed-day framing — here or in any later addition.
//
// Refresh: the widget never polls. Each render schedules ONE alarm for the
// next content boundary (the next Office hour or the next slot start), plus
// the system re-renders on date/time/timezone change via the manifest filter.
//
// iOS mirror: IntroiboWidgets/ (WidgetKit timeline).

class IntroiboWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
        scheduleNextBoundaryUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            // Clock jumps the alarm pipeline can't see: re-render immediately.
            // (Date rollover needs no broadcast — the midnight Matins boundary
            // alarm covers it; DATE_CHANGED is not deliverable to manifest
            // receivers on API 26+ anyway.)
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            ACTION_REFRESH -> refreshAll(context)
        }
    }

    override fun onDisabled(context: Context) {
        // Last widget removed: stop waking the process at boundaries.
        alarmManager(context)?.cancel(boundaryPendingIntent(context))
        super.onDisabled(context)
    }

    companion object {

        /** Fired by our own boundary alarm; triggers a re-render. */
        const val ACTION_REFRESH = "com.lampstandhq.introibo.widget.REFRESH"

        /** Re-render every instance now and re-arm the boundary alarm. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, IntroiboWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) return
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context))
            }
            scheduleNextBoundaryUpdate(context)
        }

        /**
         * The schedulable cursus: hours.json also carries the devotional
         * Office of the Dead at the same time as Matins — the widget (like
         * the Office tab's dial) only surfaces the canonical hours.
         */
        private fun canonicalHours() =
            ContentStore.hours.filter { it.slug != "office-of-the-dead" }

        // MARK: Render

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_introibo)
            val nowMinutes = OfficeSchedule.currentMinuteOfDay()

            when (WidgetConfig.mode(context)) {
                WidgetMode.OFFICE -> {
                    val hours = canonicalHours()
                    val slug = OfficeSchedule.currentHourSlug(hours, nowMinutes)
                    val hour = hours.firstOrNull { it.slug == slug }
                    views.setTextViewText(
                        R.id.widget_label,
                        context.getString(R.string.widget_label_office),
                    )
                    views.setTextViewText(R.id.widget_title, hour?.name ?: "Divine Office")
                    views.setTextViewText(
                        R.id.widget_subtitle,
                        hour?.eng ?: context.getString(R.string.widget_tap_to_pray),
                    )
                }
                WidgetMode.PRAYER -> {
                    val slot = WidgetConfig.currentSlot(context, nowMinutes)
                    val slug = WidgetConfig.slotPrayer(context, slot)
                    val prayer = ContentStore.prayers.firstOrNull { it.slug == slug }
                    views.setTextViewText(
                        R.id.widget_label,
                        context.getString(
                            when (slot) {
                                WidgetSlot.MORNING ->
                                    R.string.widget_label_morning
                                WidgetSlot.MIDDAY ->
                                    R.string.widget_label_midday
                                WidgetSlot.EVENING ->
                                    R.string.widget_label_evening
                            },
                        ),
                    )
                    views.setTextViewText(R.id.widget_title, prayer?.title ?: "Oratio")
                    views.setTextViewText(
                        R.id.widget_subtitle,
                        prayer?.eng ?: context.getString(R.string.widget_tap_to_pray),
                    )
                }
            }

            // Tap-through: a "resolve at tap time" target, so a stale render
            // can never open yesterday's hour — MainActivity resolves
            // widget:office / widget:prayer against the clock at tap.
            val tap = Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_DEEPLINK
                putExtra(
                    MainActivity.EXTRA_TARGET,
                    when (WidgetConfig.mode(context)) {
                        WidgetMode.OFFICE -> "widget:office"
                        WidgetMode.PRAYER -> "widget:prayer"
                    },
                )
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    0,
                    tap,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            return views
        }

        // MARK: Boundary scheduling

        /**
         * Arm one alarm at the next content boundary: the next Office hour
         * time (office mode) or the next slot start (prayer mode); if none
         * remain today, the first boundary tomorrow.
         */
        private fun scheduleNextBoundaryUpdate(context: Context) {
            val alarm = alarmManager(context) ?: return
            val nowMinutes = OfficeSchedule.currentMinuteOfDay()

            val todayBoundaries: List<Int> = when (WidgetConfig.mode(context)) {
                WidgetMode.OFFICE -> canonicalHours().map { it.hour * 60 + it.minute }
                WidgetMode.PRAYER ->
                    WidgetSlot.entries
                        .map { WidgetConfig.slotStart(context, it) }
            }.sorted()

            val next = todayBoundaries.firstOrNull { it > nowMinutes }
            val cal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
                if (next != null) {
                    set(java.util.Calendar.HOUR_OF_DAY, next / 60)
                    set(java.util.Calendar.MINUTE, next % 60)
                } else {
                    val first = todayBoundaries.firstOrNull() ?: 0
                    add(java.util.Calendar.DAY_OF_YEAR, 1)
                    set(java.util.Calendar.HOUR_OF_DAY, first / 60)
                    set(java.util.Calendar.MINUTE, first % 60)
                }
            }

            val pi = boundaryPendingIntent(context)
            alarm.cancel(pi)
            // Inexact by design: a widget label may lag a boundary without
            // harm (the tap resolves against the clock at tap time), and this
            // avoids the exact-alarm permission gate. Android 12+ clamps the
            // window to a 10-minute minimum, so declare that honestly.
            alarm.setWindow(
                AlarmManager.RTC,
                cal.timeInMillis,
                10 * 60 * 1000L,
                pi,
            )
        }

        private fun boundaryPendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, IntroiboWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
            }
            return PendingIntent.getBroadcast(
                context,
                1,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun alarmManager(context: Context): AlarmManager? =
            context.getSystemService(AlarmManager::class.java)
    }
}
