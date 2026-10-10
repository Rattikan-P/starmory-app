package com.example.starmory_app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * BroadcastReceiver triggered at 00:00 midnight (or on boot/time changes)
 * to automatically advance the Word of the Day on both widgets.
 */
class WidgetMidnightReceiver : BroadcastReceiver() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"

        private fun getIntSafe(
            prefs: android.content.SharedPreferences,
            key: String,
            default: Int = 0
        ): Int {
            return try {
                prefs.getInt(key, default)
            } catch (e: ClassCastException) {
                try {
                    prefs.getLong(key, default.toLong()).toInt()
                } catch (e2: ClassCastException) {
                    prefs.getString(key, null)?.toIntOrNull() ?: default
                }
            }
        }

        private fun getActiveStreak(prefs: android.content.SharedPreferences): Pair<Int, Int> {
            val streak = getIntSafe(prefs, "widget_streak")
            val shields = getIntSafe(prefs, "widget_streak_shields")
            if (streak <= 0) return streak to shields

            val lastActivityDate = prefs.getString("widget_last_activity_date", null)
                ?: return streak to shields
            val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
                isLenient = false
            }
            val lastActivity = parser.parse(lastActivityDate) ?: return streak to shields
            val lastDay = Calendar.getInstance().apply {
                time = lastActivity
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val today = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            var daysDifference = 0
            while (lastDay.before(today) && daysDifference <= 36600) {
                lastDay.add(Calendar.DAY_OF_YEAR, 1)
                daysDifference++
            }
            // One missed day is allowed; longer gaps need only one shield.
            // The shield is consumed when the user resumes learning, not at midnight.
            return if (daysDifference <= 2 || shields > 0) {
                streak to shields
            } else {
                0 to 0
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        // 1. Always ensure the next midnight alarm is scheduled
        WidgetMidnightScheduler.scheduleNextMidnight(context)

        // 2. Advance the widget word from the pre-cached vocabulary queue
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        try {
            val calendar = Calendar.getInstance()
            val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
            val year = calendar.get(Calendar.YEAR)
            val daySeed = year * 366 + dayOfYear

            val (currentStreak, shields) = getActiveStreak(prefs)
            prefs.edit().putInt("widget_streak", currentStreak)
                .putInt("widget_streak_shields", shields)
                .apply()

            val queueJson = prefs.getString("widget_vocab_queue", null)
            if (!queueJson.isNullOrEmpty()) {
                val jsonArray = JSONArray(queueJson)
                if (jsonArray.length() > 0) {
                    val dueCount = getIntSafe(prefs, "widget_due_vocabulary_count")
                        .coerceIn(0, jsonArray.length())
                    val selectionCount = if (dueCount > 0) dueCount else jsonArray.length()
                    val index = Math.floorMod(daySeed, selectionCount)
                    val vocabObj = jsonArray.getJSONObject(index)

                    val word = vocabObj.optString("word", "")
                    val trans = vocabObj.optString("translation", "")
                    val sentence = vocabObj.optString("sentence", "")
                    val imagePath = vocabObj.optString("imagePath", "")
                    val vocabId = vocabObj.optString("vocabId", "")
                    val dateStr = vocabObj.optString("date").ifEmpty {
                        SimpleDateFormat("MMM d", Locale.ENGLISH).format(Date())
                    }

                    prefs.edit().apply {
                        putBoolean("widget_has_data", true)
                        putString("widget_word", word)
                        putString("widget_translation", trans)
                        putString("widget_sentence", sentence)
                        putString("widget_image_path", imagePath)
                        putString("widget_vocab_id", vocabId)
                        putString("widget_date", dateStr)
                        apply()
                    }
                }
            }

            // Refresh 4x2 and 2x2 widgets
            val appWidgetManager = AppWidgetManager.getInstance(context)

            val widget4x2Component = ComponentName(context, VocabWidgetProvider::class.java)
            val ids4x2 = appWidgetManager.getAppWidgetIds(widget4x2Component)
            for (id in ids4x2) {
                VocabWidgetProvider.updateWidget(context, appWidgetManager, id)
            }

            val widget2x2Component = ComponentName(context, VocabCompactWidgetProvider::class.java)
            val ids2x2 = appWidgetManager.getAppWidgetIds(widget2x2Component)
            for (id in ids2x2) {
                VocabCompactWidgetProvider.updateWidget(context, appWidgetManager, id)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
