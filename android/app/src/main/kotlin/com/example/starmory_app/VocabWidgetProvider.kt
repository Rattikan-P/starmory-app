package com.example.starmory_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.io.File

/**
 * Android App Widget Provider for Starmory Personal Vocab Widget.
 *
 * Reads vocab data written by Flutter's WidgetService via home_widget,
 * then renders the 4×2 RemoteViews layout.
 *
 * Tap Actions (PendingIntents):
 *   - Tap word/translation → open Review session
 *   - Tap camera icon     → open Camera/scrapbook capture
 *   - Tap photo area      → open Scrapbook detail for this vocab
 */
class VocabWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Handle refresh action from widget button
        if (intent.action == ACTION_REFRESH) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, VocabWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, ids)
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.example.starmory_app.WIDGET_REFRESH"
        private const val PREFS_NAME = "HomeWidgetPreferences"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            // home_widget stores all values as Strings under the key directly
            val hasData   = prefs.getBoolean("widget_has_data", false)
            val word      = prefs.getString("widget_word", "") ?: ""
            val trans     = prefs.getString("widget_translation", "") ?: ""
            val pos       = prefs.getString("widget_part_of_speech", "") ?: ""
            val cefr      = prefs.getString("widget_cefr_level", "") ?: ""
            val imagePath = prefs.getString("widget_image_path", "") ?: ""
            val vocabId   = prefs.getString("widget_vocab_id", "") ?: ""
            val dateStr   = prefs.getString("widget_date", "") ?: ""
            // home_widget saves int as Int in SharedPreferences
            val retention = prefs.getInt("widget_retention", 0)

            // Choose layout based on whether we have data
            val views = if (!hasData || word.isEmpty()) {
                buildEmptyView(context)
            } else {
                buildVocabView(
                    context, word, trans, pos, cefr,
                    imagePath, vocabId, dateStr, retention
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // ─── Empty / No-data state ──────────────────────────────────────────
        private fun buildEmptyView(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_4x2)
            views.setTextViewText(R.id.widget_word, "All caught up! ✨")
            views.setTextViewText(R.id.widget_translation, "No reviews due right now")
            views.setTextViewText(R.id.widget_date, "")
            views.setTextViewText(R.id.widget_pos_badge, "")
            views.setTextViewText(R.id.widget_retention, "")
            views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            setTapActions(context, views, "", "", "review")
            return views
        }

        // ─── Main vocab card view ───────────────────────────────────────────
        private fun buildVocabView(
            context: Context,
            word: String,
            trans: String,
            pos: String,
            cefr: String,
            imagePath: String,
            vocabId: String,
            dateStr: String,
            retention: Int
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_4x2)

            // Text fields
            views.setTextViewText(R.id.widget_word, word)
            views.setTextViewText(R.id.widget_translation, trans)
            views.setTextViewText(R.id.widget_date, dateStr)
            views.setTextViewText(
                R.id.widget_pos_badge,
                if (pos.isNotEmpty()) pos.take(4).uppercase() else ""
            )
            views.setTextViewText(
                R.id.widget_retention,
                if (retention > 0) "$retention%" else ""
            )

            // Image — local file path only
            val bitmap = loadBitmapSafe(imagePath)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_image, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            }

            // Tap actions
            setTapActions(context, views, vocabId, word, "review")

            return views
        }

        // ─── PendingIntents for all tap zones ──────────────────────────────
        private fun setTapActions(
            context: Context,
            views: RemoteViews,
            vocabId: String,
            word: String,
            defaultAction: String
        ) {
            val requestCode = System.currentTimeMillis().toInt()

            // Tap word / translation → open Review tab
            val reviewIntent = buildDeepLinkIntent(context, "starmory://review", requestCode)
            views.setOnClickPendingIntent(R.id.widget_content_area, reviewIntent)

            // Tap camera icon → open Camera/capture
            val cameraIntent = buildDeepLinkIntent(context, "starmory://camera", requestCode + 1)
            views.setOnClickPendingIntent(R.id.widget_camera_btn, cameraIntent)

            // Tap image → open Scrapbook detail for this vocab
            val scrapbookUri = if (vocabId.isNotEmpty()) {
                Uri.Builder()
                    .scheme("starmory")
                    .authority("scrapbook")
                    .appendPath(vocabId)
                    .appendQueryParameter("word", word)
                    .build()
                    .toString()
            } else {
                "starmory://review"
            }
            val scrapbookIntent = buildDeepLinkIntent(context, scrapbookUri, requestCode + 2)
            views.setOnClickPendingIntent(R.id.widget_image, scrapbookIntent)

            // Refresh button
            val refreshIntent = android.app.PendingIntent.getBroadcast(
                context,
                requestCode + 3,
                Intent(ACTION_REFRESH).apply {
                    setClass(context, VocabWidgetProvider::class.java)
                },
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_btn, refreshIntent)
        }

        private fun buildDeepLinkIntent(
            context: Context,
            deepLink: String,
            requestCode: Int
        ): android.app.PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse(deepLink)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return android.app.PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun loadBitmapSafe(path: String): Bitmap? {
            return try {
                if (path.isEmpty()) return null
                val file = File(path)
                if (!file.exists()) return null

                // Decode with downsampling to avoid OOM in widget process
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeFile(path, options)
                options.inSampleSize = calculateInSampleSize(options, 200, 200)
                options.inJustDecodeBounds = false
                BitmapFactory.decodeFile(path, options)
            } catch (e: Exception) {
                null
            }
        }

        private fun calculateInSampleSize(
            options: BitmapFactory.Options,
            reqWidth: Int,
            reqHeight: Int
        ): Int {
            val (height, width) = options.outHeight to options.outWidth
            var inSampleSize = 1
            if (height > reqHeight || width > reqWidth) {
                val halfHeight = height / 2
                val halfWidth = width / 2
                while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                    inSampleSize *= 2
                }
            }
            return inSampleSize
        }
    }
}
