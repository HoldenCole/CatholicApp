package com.lampstandhq.introibo.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.lampstandhq.introibo.data.content.ContentStore

/**
 * Application class for Introibo. Initialises the [ContentStore] from
 * bundled assets and creates the notification channel used for daily
 * prayer reminders.
 */
class IntroiboApp : Application() {

    override fun onCreate() {
        super.onCreate()

        // Load all bundled JSON content into memory.
        ContentStore.init(applicationContext)

        // Create the notification channel (required on API 26+).
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            val prayerRuleChannel = NotificationChannel(
                CHANNEL_PRAYER_RULE,
                "Prayer Rule Reminders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Daily prayer rule reminders"
            }

            val officeBellsChannel = NotificationChannel(
                CHANNEL_OFFICE_BELLS,
                "Divine Office",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Divine Office hour bells"
            }

            val devotionsChannel = NotificationChannel(
                CHANNEL_DEVOTIONS,
                "Devotion Reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Rosary, stations, confession reminders"
            }

            manager.createNotificationChannels(
                listOf(prayerRuleChannel, officeBellsChannel, devotionsChannel)
            )
        }
    }

    companion object {
        const val CHANNEL_PRAYER_RULE = "introibo_prayer_rule"
        const val CHANNEL_OFFICE_BELLS = "introibo_office_bells"
        const val CHANNEL_DEVOTIONS = "introibo_devotions"
    }
}
