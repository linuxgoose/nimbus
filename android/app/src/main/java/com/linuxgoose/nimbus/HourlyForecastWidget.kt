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

class HourlyForecastWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isDarkMode = isDarkMode(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hourly_forecast_widget).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.hourly_forecast_widget_container, pendingIntent)

                // Main Data
                val location = widgetData.getString("location_name", "Location") ?: "Location"
                val journalDate = widgetData.getString("journal_date", "") ?: ""
                val currentTemp = widgetData.getString("weather_degree", "--°") ?: "--°"
                val description = widgetData.getString("weather_description", "") ?: ""
                val high = widgetData.getString("journal_high", "--°") ?: "--°"
                val low = widgetData.getString("journal_low", "--°") ?: "--°"
                val feelsLike = widgetData.getString("journal_feels_like", "--°") ?: "--°"
                val precip = widgetData.getString("weather_precip", "--") ?: "--"
                val wind = widgetData.getString("weather_wind", "--") ?: "--"
                val humidity = widgetData.getString("weather_humidity", "--") ?: "--"

                setTextViewText(R.id.hourly_forecast_date, journalDate)
                setTextViewText(R.id.hourly_forecast_location, location)
                setTextViewText(R.id.hourly_forecast_current_temp, currentTemp)
                setTextViewText(R.id.hourly_forecast_description, description)
                setTextViewText(R.id.hourly_forecast_high, high)
                setTextViewText(R.id.hourly_forecast_low, low)
                setTextViewText(R.id.hourly_forecast_feels_like, feelsLike)
                setTextViewText(R.id.hourly_forecast_precip, precip)
                setTextViewText(R.id.hourly_forecast_wind, wind)
                setTextViewText(R.id.hourly_forecast_humidity, humidity)

                // Current Icon
                val iconPath = widgetData.getString("small_weather_icon", null) ?: widgetData.getString("weather_icon", null)
                if (iconPath != null) {
                    try {
                        val options = BitmapFactory.Options().apply {
                            inSampleSize = calculateInSampleSize(this, 100, 100)
                        }
                        val bitmap = BitmapFactory.decodeFile(iconPath, options)
                        if (bitmap != null) {
                            setImageViewBitmap(R.id.hourly_forecast_current_icon, bitmap)
                        }
                    } catch (e: Exception) { /* ignore */ }
                }

                // Hourly Forecast (4 hours)
                for (i in 0 until 4) {
                    val time = widgetData.getString("hourly_forecast_time_$i", null)
                    val temp = widgetData.getString("hourly_forecast_temp_$i", null)
                    val wind = widgetData.getString("hourly_forecast_wind_$i", null)
                    val precip = widgetData.getString("hourly_forecast_precip_$i", null)
                    val icon = widgetData.getString("hourly_forecast_icon_$i", null)

                    val timeViewId = context.resources.getIdentifier("hourly_forecast_time_$i", "id", context.packageName)
                    val tempViewId = context.resources.getIdentifier("hourly_forecast_temp_$i", "id", context.packageName)
                    val windViewId = context.resources.getIdentifier("hourly_forecast_wind_$i", "id", context.packageName)
                    val precipViewId = context.resources.getIdentifier("hourly_forecast_precip_$i", "id", context.packageName)
                    val iconViewId = context.resources.getIdentifier("hourly_forecast_icon_$i", "id", context.packageName)

                    if (time != null && timeViewId != 0) {
                        setTextViewText(timeViewId, time)
                    }
                    if (temp != null && tempViewId != 0) {
                        setTextViewText(tempViewId, temp)
                    }
                    if (wind != null && windViewId != 0) {
                        setTextViewText(windViewId, wind)
                    }
                    if (precip != null && precipViewId != 0) {
                        setTextViewText(precipViewId, precip)
                    }
                    if (icon != null && iconViewId != 0) {
                        try {
                            val options = BitmapFactory.Options().apply {
                                inSampleSize = calculateInSampleSize(this, 50, 50)
                            }
                            val bitmap = BitmapFactory.decodeFile(icon, options)
                            if (bitmap != null) {
                                setImageViewBitmap(iconViewId, bitmap)
                            }
                        } catch (e: Exception) { /* ignore */ }
                    }
                }

                // Background
                val backgroundColor = widgetData.getString("background_color", null)
                if (backgroundColor != null) {
                    try {
                        setInt(R.id.hourly_forecast_widget_container, "setBackgroundColor", Color.parseColor(backgroundColor))
                    } catch (e: Exception) { /* ignore */ }
                } else {
                    val defaultBg = if (isDarkMode) "#212121" else "#FAFBFC"
                    setInt(R.id.hourly_forecast_widget_container, "setBackgroundColor", Color.parseColor(defaultBg))
                }

                // Colors
                val primaryTextColor = if (isDarkMode) Color.WHITE else Color.parseColor("#2D3436")
                val secondaryTextColor = if (isDarkMode) Color.parseColor("#D1D5DB") else Color.parseColor("#6B7280")
                val tertiaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#94A3B8")
                val quaternaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#64748B")

                // Primary text
                listOf(R.id.hourly_forecast_current_temp, R.id.hourly_forecast_high, R.id.hourly_forecast_feels_like, R.id.hourly_forecast_precip)
                    .forEach { try { setTextColor(it, primaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Secondary text
                listOf(R.id.hourly_forecast_location, R.id.hourly_forecast_description)
                    .forEach { try { setTextColor(it, secondaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Tertiary text
                listOf(R.id.hourly_forecast_date, R.id.hourly_forecast_low)
                    .forEach { try { setTextColor(it, tertiaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Quaternary text
                listOf(R.id.hourly_forecast_wind, R.id.hourly_forecast_humidity)
                    .forEach { try { setTextColor(it, quaternaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Hourly forecast temps and times
                for (i in 0 until 4) {
                    val timeViewId = context.resources.getIdentifier("hourly_forecast_time_$i", "id", context.packageName)
                    val tempViewId = context.resources.getIdentifier("hourly_forecast_temp_$i", "id", context.packageName)
                    val windViewId = context.resources.getIdentifier("hourly_forecast_wind_$i", "id", context.packageName)
                    val precipViewId = context.resources.getIdentifier("hourly_forecast_precip_$i", "id", context.packageName)
                    
                    if (timeViewId != 0) {
                        try { setTextColor(timeViewId, tertiaryTextColor) } catch (e: Exception) { /* ignore */ }
                    }
                    if (tempViewId != 0) {
                        try { setTextColor(tempViewId, primaryTextColor) } catch (e: Exception) { /* ignore */ }
                    }
                    if (windViewId != 0) {
                        try { setTextColor(windViewId, quaternaryTextColor) } catch (e: Exception) { /* ignore */ }
                    }
                    if (precipViewId != 0) {
                        try { setTextColor(precipViewId, quaternaryTextColor) } catch (e: Exception) { /* ignore */ }
                    }
                }
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
