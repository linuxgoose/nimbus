package com.yoshi.rain

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SmallWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isDarkMode = isDarkMode(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.small_widget).apply {
                
                // Open App on Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_small_container, pendingIntent)

                // Location
                setTextViewText(R.id.small_location, widgetData.getString("small_location", "Location") ?: "Location")

                // Time
                setTextViewText(R.id.small_time, widgetData.getString("small_time", "--:--") ?: "--:--")

                // Temperature
                setTextViewText(R.id.small_temperature, widgetData.getString("small_temperature", "--°") ?: "--°")

                // Precipitation
                setTextViewText(R.id.small_precipitation, widgetData.getString("small_precipitation", "--") ?: "--")

                // Weather Icon
                val imagePath = widgetData.getString("small_weather_icon", null)
                if (imagePath != null) {
                    val options = BitmapFactory.Options().apply {
                        inSampleSize = calculateInSampleSize(this, 40, 40)
                    }
                    val bitmap = BitmapFactory.decodeFile(imagePath, options)
                    if (bitmap != null) {
                        setImageViewBitmap(R.id.small_weather_icon, bitmap)
                    }
                }

                // --- BACKGROUND LOGIC ---
                val backgroundColor = widgetData.getString("background_color", null)
                if (backgroundColor != null) {
                    try {
                        setInt(R.id.widget_small_container, "setBackgroundColor", Color.parseColor(backgroundColor))
                    } catch (e: Exception) { /* ignore */ }
                } else {
                    val defaultBg = if (isDarkMode) "#212121" else "#FFFFFF"
                    setInt(R.id.widget_small_container, "setBackgroundColor", Color.parseColor(defaultBg))
                }

                // --- TEXT COLOR LOGIC ---
                val textColor = widgetData.getString("text_color", null)
                val finalTextColor = if (textColor != null) {
                    try { Color.parseColor(textColor) } catch (e: Exception) { 
                        if (isDarkMode) Color.WHITE else Color.BLACK 
                    }
                } else {
                    if (isDarkMode) Color.WHITE else Color.BLACK
                }

                val textViews = listOf(
                    R.id.small_location,
                    R.id.small_time,
                    R.id.small_temperature,
                    R.id.small_precipitation
                )
                textViews.forEach { setTextColor(it, finalTextColor) }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val (height: Int, width: Int) = options.run { outHeight to outWidth }
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            val halfHeight: Int = height / 2
            val halfWidth: Int = width / 2

            while (halfHeight / inSampleSize >= reqHeight && halfWidth / inSampleSize >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private fun isDarkMode(context: Context): Boolean {
        val darkModeFlag = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return darkModeFlag == Configuration.UI_MODE_NIGHT_YES
    }
}
