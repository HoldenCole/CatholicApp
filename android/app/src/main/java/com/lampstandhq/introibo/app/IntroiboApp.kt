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
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Daily prayer and devotion reminders"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    companion object {
        const val CHANNEL_ID = "introibo_reminders"
    }
}
