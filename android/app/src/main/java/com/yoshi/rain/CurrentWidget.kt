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

class CurrentWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isDarkMode = isDarkMode(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.current_widget).apply {
                
                // Open App on Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                // 1. Location Data
                val location = widgetData.getString("location_name", "Unknown") ?: "Unknown"
                val country = widgetData.getString("country_name", "") ?: ""
                val fullLocation = if (country.isNotEmpty()) "$location, $country" else location
                setTextViewText(R.id.location_text, fullLocation)

                // 2. Weather Data Strings
                setTextViewText(R.id.weather_degree, widgetData.getString("weather_degree", "--°") ?: "--°")
                setTextViewText(R.id.weather_description, widgetData.getString("weather_description", "Unknown") ?: "Unknown")
                setTextViewText(R.id.weather_wind, widgetData.getString("weather_wind", "--") ?: "--")
                setTextViewText(R.id.weather_humidity, widgetData.getString("weather_humidity", "--") ?: "--")
                setTextViewText(R.id.weather_visibility, widgetData.getString("weather_visibility", "--") ?: "--")

                // 3. Weather Icon
                val imagePath = widgetData.getString("weather_icon", null)
                if (imagePath != null) {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    if (bitmap != null) {
                        setImageViewBitmap(R.id.weather_icon, bitmap)
                    }
                }

                // --- 4. BACKGROUND LOGIC (Matches Hourly) ---
                val backgroundColor = widgetData.getString("background_color", null)
                if (backgroundColor != null) {
                    try {
                        setInt(R.id.widget_container, "setBackgroundColor", Color.parseColor(backgroundColor))
                    } catch (e: Exception) { /* ignore */ }
                } else {
                    val defaultBg = if (isDarkMode) "#212121" else "#FFFFFF"
                    setInt(R.id.widget_container, "setBackgroundColor", Color.parseColor(defaultBg))
                }

                // --- 5. TEXT COLOR LOGIC (Matches Hourly) ---
                val textColor = widgetData.getString("text_color", null)
                val finalTextColor = if (textColor != null) {
                    try { Color.parseColor(textColor) } catch (e: Exception) { 
                        if (isDarkMode) Color.WHITE else Color.BLACK 
                    }
                } else {
                    if (isDarkMode) Color.WHITE else Color.BLACK
                }

                val textViews = listOf(
                    R.id.location_text,
                    R.id.weather_degree, 
                    R.id.weather_description,
                    R.id.weather_wind, 
                    R.id.weather_humidity, 
                    R.id.weather_visibility
                )
                textViews.forEach { setTextColor(it, finalTextColor) }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    // Helper function to detect System Dark Mode
    private fun isDarkMode(context: Context): Boolean {
        val darkModeFlag = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return darkModeFlag == Configuration.UI_MODE_NIGHT_YES
    }
}