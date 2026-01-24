package com.linuxgoose.nimbus

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

                // Time
                setTextViewText(R.id.small_time, widgetData.getString("small_time", "--:--") ?: "--:--")

                // Date
                setTextViewText(R.id.small_date, widgetData.getString("small_date", "") ?: "")

                // Location
                setTextViewText(R.id.small_location, widgetData.getString("small_location", "Location") ?: "Location")

                // Temperature
                setTextViewText(R.id.small_temperature, widgetData.getString("small_temperature", "--°") ?: "--°")

                // Precipitation
                setTextViewText(R.id.small_precipitation, widgetData.getString("small_precipitation", "--") ?: "--")

                // Description
                setTextViewText(R.id.small_description, widgetData.getString("small_description", "") ?: "")

                // Weather Icon
                val imagePath = widgetData.getString("small_weather_icon", null)
                if (imagePath != null) {
                    val options = BitmapFactory.Options().apply {
                        inSampleSize = calculateInSampleSize(this, 32, 32)
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
                    val defaultBg = if (isDarkMode) "#212121" else "#FAFBFC"
                    setInt(R.id.widget_small_container, "setBackgroundColor", Color.parseColor(defaultBg))
                }

                // --- TEXT COLOR LOGIC (MATCHING JOURNAL WIDGET) ---
                val primaryTextColor = if (isDarkMode) Color.WHITE else Color.parseColor("#2D3436")
                val secondaryTextColor = if (isDarkMode) Color.parseColor("#D1D5DB") else Color.parseColor("#6B7280")
                val tertiaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#94A3B8")
                val quaternaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#64748B")

                // Primary text (time, temperature)
                setTextColor(R.id.small_time, primaryTextColor)
                setTextColor(R.id.small_temperature, primaryTextColor)
                
                // Secondary text (location, description)
                setTextColor(R.id.small_location, secondaryTextColor)
                setTextColor(R.id.small_description, secondaryTextColor)
                
                // Tertiary text (date)
                setTextColor(R.id.small_date, tertiaryTextColor)
                
                // Quaternary text (precipitation)
                setTextColor(R.id.small_precipitation, quaternaryTextColor)
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
