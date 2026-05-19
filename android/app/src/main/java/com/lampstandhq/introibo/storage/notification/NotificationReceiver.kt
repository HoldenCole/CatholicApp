package com.lampstandhq.introibo.storage.notification

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Calendar

/**
 * BroadcastReceiver that fires when a scheduled prayer alarm goes off.
 * Builds and displays a notification, then re-schedules the alarm for
 * the next week (AlarmManager exact alarms are one-shot on modern
 * Android).
 */
class NotificationReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(PrayerNotificationManager.EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(PrayerNotificationManager.EXTRA_BODY).orEmpty()
        val scheduleId = intent.getStringExtra(PrayerNotificationManager.EXTRA_SCHEDULE_ID).orEmpty()

        val notificationId = scheduleId.hashCode()
        val channelId = PrayerNotificationManager.channelForSchedule(scheduleId)

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .apply { if (body.isNotEmpty()) setContentText(body) }
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS permission not granted — silently ignore.
        }

        // Re-schedule this alarm for the same time next week so it repeats.
        rescheduleNextWeek(context, intent)
    }

    /**
     * Exact alarms on Android 12+ are one-shot, so we re-schedule the
     * alarm 7 days from now to simulate weekly repeating behaviour.
     */
    private fun rescheduleNextWeek(context: Context, originalIntent: Intent) {
        val scheduleId = originalIntent.getStringExtra(PrayerNotificationManager.EXTRA_SCHEDULE_ID) ?: return
        val title = originalIntent.getStringExtra(PrayerNotificationManager.EXTRA_TITLE) ?: return
        val body = originalIntent.getStringExtra(PrayerNotificationManager.EXTRA_BODY).orEmpty()

        val nextWeek = Calendar.getInstance().apply {
            add(Calendar.WEEK_OF_YEAR, 1)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val newIntent = Intent(context, NotificationReceiver::class.java).apply {
            action = "com.lampstandhq.introibo.PRAYER_ALARM"
            putExtra(PrayerNotificationManager.EXTRA_SCHEDULE_ID, scheduleId)
            putExtra(PrayerNotificationManager.EXTRA_TITLE, title)
            putExtra(PrayerNotificationManager.EXTRA_BODY, body)
        }

        // Use the same request code so we overwrite any stale pending intent.
        val requestCode = originalIntent.getStringExtra(PrayerNotificationManager.EXTRA_SCHEDULE_ID)
            ?.let { "introibo.$it.reschedule".hashCode() }
            ?: return

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            newIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                nextWeek.timeInMillis,
                pendingIntent,
            )
        } catch (_: SecurityException) {
            // SCHEDULE_EXACT_ALARM not granted — silently degrade.
        }
    }
}
