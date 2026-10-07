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
    }

    override fun onReceive(context: Context, intent: Intent?) {
        // 1. Always ensure the next midnight alarm is scheduled
        WidgetMidnightScheduler.scheduleNextMidnight(context)

        // 2. Advance the widget word from the pre-cached vocabulary queue
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val queueJson = prefs.getString("widget_vocab_queue", null) ?: return

        try {
            val jsonArray = JSONArray(queueJson)
            if (jsonArray.length() == 0) return

            val calendar = Calendar.getInstance()
            val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
            val year = calendar.get(Calendar.YEAR)
            val daySeed = year * 366 + dayOfYear

            val index = Math.abs(daySeed % jsonArray.length())
            val vocabObj = jsonArray.getJSONObject(index)

            val word = vocabObj.optString("word", "")
            val trans = vocabObj.optString("translation", "")
            val sentence = vocabObj.optString("sentence", "")
            val imagePath = vocabObj.optString("imagePath", "")
            val vocabId = vocabObj.optString("vocabId", "")

            val dateSdf = SimpleDateFormat("MMM d", Locale.ENGLISH)
            val dateStr = dateSdf.format(Date())

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
