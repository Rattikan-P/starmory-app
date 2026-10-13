package com.example.starmory_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.io.File

/**
 * Android App Widget Provider for Starmory Personal Vocab Widget (4x2 Standard).
 */
class VocabWidgetProvider : AppWidgetProvider() {

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetMidnightScheduler.scheduleNextMidnight(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        WidgetMidnightScheduler.scheduleNextMidnight(context)
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val hasData   = prefs.getBoolean("widget_has_data", false)
            val hasError  = prefs.getBoolean("widget_has_error", false)
            val word      = prefs.getString("widget_word", "") ?: ""
            val trans     = prefs.getString("widget_translation", "") ?: ""
            val sentence  = prefs.getString("widget_sentence", "") ?: ""
            val imagePath = prefs.getString("widget_image_path", "") ?: ""
            val vocabId   = prefs.getString("widget_vocab_id", "") ?: ""
            val dateStr   = prefs.getString("widget_date", "") ?: ""
            val streak    = getIntSafe(prefs, "widget_streak", 0)

            val views = if (hasError) {
                buildErrorView(context)
            } else if (!hasData || word.isEmpty()) {
                buildEmptyView(context)
            } else {
                buildVocabView(
                    context, word, trans, sentence,
                    imagePath, vocabId, dateStr, streak
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        private fun getIntSafe(prefs: SharedPreferences, key: String, default: Int = 0): Int {
            return try {
                prefs.getInt(key, default)
            } catch (e: Exception) {
                try {
                    prefs.getLong(key, default.toLong()).toInt()
                } catch (e2: Exception) {
                    try {
                        prefs.getString(key, null)?.toIntOrNull() ?: default
                    } catch (e3: Exception) {
                        default
                    }
                }
            }
        }

        // ─── Empty State: Purple background + Mascot + "Scan Photo" ───────
        private fun buildEmptyView(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_4x2_empty)
            val requestCode = System.currentTimeMillis().toInt()
            val cameraIntent = buildDeepLinkIntent(context, "starmory://camera", requestCode)
            views.setOnClickPendingIntent(R.id.widget_root, cameraIntent)
            return views
        }

        private fun buildErrorView(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_4x2_error)
            val requestCode = System.currentTimeMillis().toInt()
            val homeIntent = buildDeepLinkIntent(context, "starmory://home", requestCode)
            views.setOnClickPendingIntent(R.id.widget_root, homeIntent)
            return views
        }

        // ─── Data State: White Card + Image (Rounded) + Word + Sentence + Camera ─────
        private fun buildVocabView(
            context: Context,
            word: String,
            trans: String,
            sentence: String,
            imagePath: String,
            vocabId: String,
            dateStr: String,
            streak: Int
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_4x2)

            // Text fields
            views.setTextViewText(R.id.widget_word, word)
            views.setTextViewText(R.id.widget_translation, trans)
            views.setTextViewText(
                R.id.widget_sentence,
                if (sentence.isNotEmpty()) "“$sentence”" else ""
            )
            views.setTextViewText(R.id.widget_date, if (dateStr.isNotEmpty()) dateStr else "Today")
            views.setTextViewText(
                R.id.widget_streak_badge,
                if (streak > 0) "🔥$streak" else "🔥0"
            )

            // Image: Process with Matrix center-crop and 18dp rounded corners (preserving aspect ratio)
            val rawBitmap = loadBitmapSafe(imagePath)
            if (rawBitmap != null) {
                val roundedBitmap = getRoundedCroppedBitmap(rawBitmap, 320, 320, 18f, context)
                views.setImageViewBitmap(R.id.widget_image, roundedBitmap)
            } else {
                views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            }

            // Deep link tap actions
            setTapActions(context, views, vocabId, word, imagePath)

            return views
        }

        private fun setTapActions(
            context: Context,
            views: RemoteViews,
            vocabId: String,
            word: String,
            imagePath: String
        ) {
            val requestCode = System.currentTimeMillis().toInt()

            // Open the scrapbook created from this photo and vocabulary.
            val scrapbookUri = Uri.parse("starmory://scrapbook-day").buildUpon()
                .appendQueryParameter("vocabId", vocabId)
                .appendQueryParameter("word", word)
                .appendQueryParameter("image", imagePath)
                .build()
            val scrapbookIntent = buildDeepLinkIntent(context, scrapbookUri.toString(), requestCode)
            views.setOnClickPendingIntent(R.id.widget_root, scrapbookIntent)
            views.setOnClickPendingIntent(R.id.widget_content_area, scrapbookIntent)
            views.setOnClickPendingIntent(R.id.widget_image, scrapbookIntent)
            views.setOnClickPendingIntent(R.id.widget_date, scrapbookIntent)

            // 2. Tap streak badge → open Progress tab
            val progressIntent = buildDeepLinkIntent(context, "starmory://home?tab=progress", requestCode + 1)
            views.setOnClickPendingIntent(R.id.widget_streak_badge, progressIntent)

            // 3. Tap camera icon → open Camera
            val cameraIntent = buildDeepLinkIntent(context, "starmory://camera", requestCode + 2)
            views.setOnClickPendingIntent(R.id.widget_camera_btn, cameraIntent)
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

        private fun getRoundedCroppedBitmap(
            src: Bitmap,
            targetW: Int,
            targetH: Int,
            cornerRadiusDp: Float,
            context: Context
        ): Bitmap {
            return try {
                val density = context.resources.displayMetrics.density
                val radiusPx = cornerRadiusDp * density

                val srcW = src.width.toFloat()
                val srcH = src.height.toFloat()
                val scale = Math.max(targetW / srcW, targetH / srcH)
                val scaledW = srcW * scale
                val scaledH = srcH * scale
                val dx = (targetW - scaledW) / 2f
                val dy = (targetH - scaledH) / 2f

                val output = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(output)

                val shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                val matrix = Matrix().apply {
                    setScale(scale, scale)
                    postTranslate(dx, dy)
                }
                shader.setLocalMatrix(matrix)

                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.shader = shader
                }

                val rect = RectF(0f, 0f, targetW.toFloat(), targetH.toFloat())
                canvas.drawRoundRect(rect, radiusPx, radiusPx, paint)

                output
            } catch (e: Exception) {
                src
            }
        }

        private fun loadBitmapSafe(path: String): Bitmap? {
            return try {
                if (path.isEmpty()) return null
                val cleanPath = if (path.startsWith("file://")) {
                    Uri.parse(path).path ?: path.substring(7)
                } else {
                    path
                }
                val file = File(cleanPath)
                if (!file.exists() || file.length() == 0L) return null

                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeFile(cleanPath, options)
                if (options.outWidth <= 0 || options.outHeight <= 0) return null

                options.inSampleSize = calculateInSampleSize(options, 320, 320)
                options.inJustDecodeBounds = false
                BitmapFactory.decodeFile(cleanPath, options)
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
