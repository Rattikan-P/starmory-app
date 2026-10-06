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
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.io.File

/**
 * Android App Widget Provider for Starmory 2x2 Compact Vocab Widget.
 */
class VocabCompactWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
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
            val word      = prefs.getString("widget_word", "") ?: ""
            val trans     = prefs.getString("widget_translation", "") ?: ""
            val imagePath = prefs.getString("widget_image_path", "") ?: ""
            val vocabId   = prefs.getString("widget_vocab_id", "") ?: ""
            val streak    = getIntSafe(prefs, "widget_streak", 0)

            val views = if (!hasData || word.isEmpty()) {
                buildEmptyView(context)
            } else {
                buildVocabView(context, word, trans, imagePath, vocabId, streak)
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
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_2x2_empty)
            val requestCode = System.currentTimeMillis().toInt()
            val cameraIntent = buildDeepLinkIntent(context, "starmory://camera", requestCode)
            views.setOnClickPendingIntent(R.id.widget_root, cameraIntent)
            return views
        }

        // ─── Data State: Full Photo (Rounded) + Scrim + Streak + Word + Camera ──
        private fun buildVocabView(
            context: Context,
            word: String,
            trans: String,
            imagePath: String,
            vocabId: String,
            streak: Int
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_vocab_2x2)

            views.setTextViewText(R.id.widget_word, word)
            views.setTextViewText(R.id.widget_translation, trans)
            views.setTextViewText(
                R.id.widget_streak_badge,
                if (streak > 0) "🔥$streak" else "🔥0"
            )

            // Load and process image with aspect-ratio-preserving matrix center-crop + 28dp rounded corners + bottom gradient
            val rawBitmap = loadBitmapSafe(imagePath)
            if (rawBitmap != null) {
                val cardBitmap = getRoundedCroppedBitmap(rawBitmap, 400, 400, 28f, context, addBottomScrim = true)
                views.setImageViewBitmap(R.id.widget_image, cardBitmap)
            } else {
                views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            }

            setTapActions(context, views, vocabId, word)
            return views
        }

        private fun setTapActions(
            context: Context,
            views: RemoteViews,
            vocabId: String,
            word: String
        ) {
            val requestCode = System.currentTimeMillis().toInt() + 100

            // 1. Tap word / content -> open Vocab detail
            val wordDeepLink = if (vocabId.isNotEmpty()) {
                "starmory://vocab?id=$vocabId&word=$word"
            } else {
                "starmory://review"
            }
            val wordIntent = buildDeepLinkIntent(context, wordDeepLink, requestCode)
            views.setOnClickPendingIntent(R.id.widget_content_area, wordIntent)
            views.setOnClickPendingIntent(R.id.widget_root, wordIntent)

            // 2. Tap streak badge -> open Progress tab
            val progressIntent = buildDeepLinkIntent(context, "starmory://home?tab=progress", requestCode + 1)
            views.setOnClickPendingIntent(R.id.widget_streak_badge, progressIntent)

            // 3. Tap camera icon -> open Camera
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

        /**
         * Center-crops using Matrix to preserve natural aspect ratio (no stretching/squishing),
         * draws rounded corners, and optionally renders a bottom gradient scrim.
         */
        private fun getRoundedCroppedBitmap(
            src: Bitmap,
            targetW: Int,
            targetH: Int,
            cornerRadiusDp: Float,
            context: Context,
            addBottomScrim: Boolean = false
        ): Bitmap {
            return try {
                val density = context.resources.displayMetrics.density
                val radiusPx = cornerRadiusDp * density

                // Calculate matrix scale that preserves aspect ratio without squishing
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

                if (addBottomScrim) {
                    val gradientShader = LinearGradient(
                        0f, targetH * 0.45f,
                        0f, targetH.toFloat(),
                        intArrayOf(0x00000000, 0x55000000, 0xE6000000.toInt()),
                        floatArrayOf(0.0f, 0.5f, 1.0f),
                        Shader.TileMode.CLAMP
                    )
                    val scrimPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        this.shader = gradientShader
                    }
                    canvas.drawRoundRect(rect, radiusPx, radiusPx, scrimPaint)
                }

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

                options.inSampleSize = calculateInSampleSize(options, 400, 400)
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
