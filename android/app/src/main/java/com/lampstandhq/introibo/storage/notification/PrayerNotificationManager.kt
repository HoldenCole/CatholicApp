package com.lampstandhq.introibo.storage.notification

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.lampstandhq.introibo.app.IntroiboApp
import java.util.Calendar

/**
 * Schedules and cancels prayer notification alarms using [AlarmManager].
 * Ported from iOS Introibo/Storage/NotificationManager.swift,
 * redesigned for Android's alarm + BroadcastReceiver model.
 *
 * Each enabled [NotificationSchedule] results in one exact repeating
 * alarm per active weekday. Alarms fire into [NotificationReceiver],
 * which builds and displays the notification.
 */
class PrayerNotificationManager(private val context: Context) {

    companion object {
        // Intent extras
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_SCHEDULE_ID = "extra_schedule_id"

        // Notification titles derived from schedule id prefixes
        private val OFFICE_HOUR_NAMES = mapOf(
            "matutinum" to "Matins",
            "laudes" to "Lauds",
            "prima" to "Prime",
            "tertia" to "Terce",
            "sexta" to "Sext",
            "nona" to "None",
            "vesperae" to "Vespers",
            "completorium" to "Compline",
        )

        /**
         * Returns the appropriate notification channel ID for a given schedule ID.
         * Routes:
         *   - "rule.*"      -> Prayer Rule Reminders (IMPORTANCE_HIGH)
         *   - "office.*"    -> Divine Office (IMPORTANCE_DEFAULT)
         *   - "devotion.*"  -> Devotion Reminders (IMPORTANCE_DEFAULT)
         *   - anything else -> Prayer Rule Reminders (fallback)
         */
        fun channelForSchedule(scheduleId: String): String = when {
            scheduleId.startsWith("rule.") -> IntroiboApp.CHANNEL_PRAYER_RULE
            scheduleId.startsWith("office.") -> IntroiboApp.CHANNEL_OFFICE_BELLS
            scheduleId.startsWith("devotion.") -> IntroiboApp.CHANNEL_DEVOTIONS
            else -> IntroiboApp.CHANNEL_PRAYER_RULE
        }
    }

    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    init {
        createNotificationChannel()
    }

    // -----------------------------------------------------------------------
    // Channel
    // -----------------------------------------------------------------------

    private fun createNotificationChannel() {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val prayerRuleChannel = NotificationChannel(
            IntroiboApp.CHANNEL_PRAYER_RULE,
            "Prayer Rule Reminders",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Daily prayer rule reminders"
        }

        val officeBellsChannel = NotificationChannel(
            IntroiboApp.CHANNEL_OFFICE_BELLS,
            "Divine Office",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Divine Office hour bells"
        }

        val devotionsChannel = NotificationChannel(
            IntroiboApp.CHANNEL_DEVOTIONS,
            "Devotion Reminders",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Rosary, stations, confession reminders"
        }

        nm.createNotificationChannels(
            listOf(prayerRuleChannel, officeBellsChannel, devotionsChannel)
        )
    }

    // -----------------------------------------------------------------------
    // Schedule / cancel
    // -----------------------------------------------------------------------

    /**
     * Schedules all enabled notifications. Cancels every existing Introibo
     * alarm first, then re-creates them from scratch, matching the iOS
     * implementation's semantics.
     */
    suspend fun scheduleAll(store: NotificationStore) {
        cancelAll(store)

        val schedules = store.all().filter { it.isEnabled }
        for (schedule in schedules) {
            val (title, body) = resolveContent(schedule)

            for (day in schedule.days) {
                val requestCode = requestCode(schedule.id, day)
                val intent = buildIntent(schedule.id, title, body)
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    requestCode,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )

                val triggerTime = nextTriggerTime(day, schedule.hour, schedule.minute)
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent,
                )
            }
        }
    }

    /**
     * Cancels alarms for a single schedule id.
     */
    fun cancel(scheduleId: String) {
        // A schedule can have alarms for up to 7 days (1-7).
        for (day in 1..7) {
            val requestCode = requestCode(scheduleId, day)
            val intent = buildIntent(scheduleId, "", "")
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
    }

    /**
     * Cancels all Introibo alarms by iterating every stored schedule.
     */
    suspend fun cancelAll(store: NotificationStore) {
        val schedules = store.all()
        for (schedule in schedules) {
            cancel(schedule.id)
        }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /**
     * Resolves a human-readable title and body from the schedule id,
     * mirroring the iOS switch/case logic.
     */
    private fun resolveContent(schedule: NotificationSchedule): Pair<String, String> {
        val id = schedule.id
        return when {
            id.startsWith("rule.") -> {
                val period = id.removePrefix("rule.")
                val title = when (period) {
                    "morning" -> "Morning Prayer Rule"
                    "midday" -> "Midday Prayer Rule"
                    "evening" -> "Evening Prayer Rule"
                    "daily" -> "Daily Prayer Rule"
                    else -> "Prayer Rule"
                }
                title to "Time for your prayers."
            }

            id.startsWith("devotion.") -> {
                val key = id.removePrefix("devotion.")
                val title = when (key) {
                    "office" -> "Divine Office"
                    "rosary" -> "The Holy Rosary"
                    "stations" -> "Stations of the Cross"
                    "confession" -> "Confession"
                    else -> "Devotion"
                }
                title to "Time for your devotion."
            }

            id.startsWith("office.") -> {
                val slug = id.removePrefix("office.")
                val title = OFFICE_HOUR_NAMES[slug] ?: "Divine Office"
                title to "Time for your devotion."
            }

            id.startsWith("prayer.") -> {
                val slug = id.removePrefix("prayer.")
                // On Android we don't have the content store at alarm-schedule
                // time, so we pass the slug as the title. The full title can
                // be resolved at display time if a ContentStore reference is
                // available; otherwise the slug is a reasonable fallback.
                slug.replaceFirstChar { it.uppercase() } to ""
            }

            else -> "Introibo" to "Time for your prayers."
        }
    }

    private fun buildIntent(scheduleId: String, title: String, body: String): Intent =
        Intent(context, NotificationReceiver::class.java).apply {
            action = "com.lampstandhq.introibo.PRAYER_ALARM"
            putExtra(EXTRA_SCHEDULE_ID, scheduleId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }

    /**
     * Computes the next calendar trigger time for a given weekday (1 = Sunday
     * through 7 = Saturday, matching [Calendar.DAY_OF_WEEK]), hour, and minute.
     * If the computed time is in the past, it rolls forward to the next week.
     */
    private fun nextTriggerTime(dayOfWeek: Int, hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.DAY_OF_WEEK, dayOfWeek)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (target.before(now)) {
            target.add(Calendar.WEEK_OF_YEAR, 1)
        }
        return target.timeInMillis
    }

    /**
     * Deterministic request code derived from the schedule id + day so each
     * alarm can be individually cancelled.
     */
    private fun requestCode(scheduleId: String, day: Int): Int =
        "introibo.$scheduleId.day$day".hashCode()
}
