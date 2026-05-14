package com.lampstandhq.introibo.storage.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Re-schedules all enabled prayer notifications after a device reboot.
 *
 * AlarmManager alarms are lost when the device restarts, so this receiver
 * listens for [Intent.ACTION_BOOT_COMPLETED] and reconstructs them from
 * the persisted [NotificationStore].
 *
 * Registered in AndroidManifest.xml:
 * ```xml
 * <receiver android:name=".BootReceiver" android:exported="true">
 *     <intent-filter>
 *         <action android:name="android.intent.action.BOOT_COMPLETED" />
 *     </intent-filter>
 * </receiver>
 * ```
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val pendingResult = goAsync()
        val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

        scope.launch {
            try {
                val store = NotificationStore(context)
                val manager = PrayerNotificationManager(context)
                manager.scheduleAll(store)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
