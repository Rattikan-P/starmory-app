package com.example.starmory_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Schedules exact daily midnight (00:00) alarms to trigger automatic widget updates
 * without requiring the user to open the Flutter app.
 */
object WidgetMidnightScheduler {
    const val ACTION_MIDNIGHT_UPDATE = "com.example.starmory_app.ACTION_MIDNIGHT_UPDATE"
    private const val REQUEST_CODE = 4001

    fun scheduleNextMidnight(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        val intent = Intent(context, WidgetMidnightReceiver::class.java).apply {
            action = ACTION_MIDNIGHT_UPDATE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Calculate next midnight + 1 second (00:00:01 of tomorrow)
        val calendar = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 1)
            set(Calendar.MILLISECOND, 0)
        }

        val triggerTime = calendar.timeInMillis

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC,
                    triggerTime,
                    pendingIntent
                )
            }
        } catch (e: SecurityException) {
            // Fallback for Android 12+ if exact alarm permission is restricted
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC,
                triggerTime,
                pendingIntent
            )
        }
    }
}
