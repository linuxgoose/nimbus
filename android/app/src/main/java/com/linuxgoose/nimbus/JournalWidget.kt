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

class JournalWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isDarkMode = isDarkMode(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.journal_widget_small).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.journal_widget_container, pendingIntent)

                // Journal Data
                val location = widgetData.getString("location_name", "Location") ?: "Location"
                val journalDate = widgetData.getString("journal_date", "") ?: ""
                val temp = widgetData.getString("weather_degree", "--°") ?: "--°"
                val description = widgetData.getString("weather_description", "") ?: ""
                val summary = widgetData.getString("friendly_summary", "") ?: ""
                val high = widgetData.getString("journal_high", "--°") ?: "--°"
                val low = widgetData.getString("journal_low", "--°") ?: "--°"
                val feelsLike = widgetData.getString("journal_feels_like", "--°") ?: "--°"
                val precip = widgetData.getString("weather_precip", "--") ?: "--"
                val wind = widgetData.getString("weather_wind", "--") ?: "--"
                val humidity = widgetData.getString("weather_humidity", "--") ?: "--"

                setTextViewText(R.id.journal_date, journalDate)
                setTextViewText(R.id.journal_location, location)
                setTextViewText(R.id.journal_temp, temp)
                setTextViewText(R.id.journal_description, description)
                setTextViewText(R.id.journal_summary, summary)
                setTextViewText(R.id.journal_high, high)
                setTextViewText(R.id.journal_low, low)
                setTextViewText(R.id.journal_feels_like, feelsLike)
                setTextViewText(R.id.journal_precip, precip)
                setTextViewText(R.id.journal_wind, wind)
                setTextViewText(R.id.journal_humidity, humidity)

                // Icon
                val iconPath = widgetData.getString("small_weather_icon", null) ?: widgetData.getString("weather_icon", null)
                if (iconPath != null) {
                    try {
                        val options = BitmapFactory.Options().apply {
                            inSampleSize = calculateInSampleSize(this, 100, 100)
                        }
                        val bitmap = BitmapFactory.decodeFile(iconPath, options)
                        if (bitmap != null) {
                            setImageViewBitmap(R.id.journal_icon, bitmap)
                        }
                    } catch (e: Exception) { /* ignore */ }
                }

                // Background
                val backgroundColor = widgetData.getString("background_color", null)
                if (backgroundColor != null) {
                    try {
                        setInt(R.id.journal_widget_container, "setBackgroundColor", Color.parseColor(backgroundColor))
                    } catch (e: Exception) { /* ignore */ }
                } else {
                    val defaultBg = if (isDarkMode) "#212121" else "#FAFBFC"
                    setInt(R.id.journal_widget_container, "setBackgroundColor", Color.parseColor(defaultBg))
                }

                // Colors
                val primaryTextColor = if (isDarkMode) Color.WHITE else Color.parseColor("#2D3436")
                val secondaryTextColor = if (isDarkMode) Color.parseColor("#D1D5DB") else Color.parseColor("#6B7280")
                val tertiaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#94A3B8")
                val quaternaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#64748B")

                // Primary text (temp, high, feels like, precip)
                listOf(R.id.journal_temp, R.id.journal_high, R.id.journal_feels_like, R.id.journal_precip)
                    .forEach { try { setTextColor(it, primaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Secondary text (location, description)
                listOf(R.id.journal_location, R.id.journal_description)
                    .forEach { try { setTextColor(it, secondaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Tertiary text (date, summary, low)
                listOf(R.id.journal_date, R.id.journal_summary, R.id.journal_low)
                    .forEach { try { setTextColor(it, tertiaryTextColor) } catch (e: Exception) { /* ignore */ } }

                // Quaternary text (wind, humidity)
                listOf(R.id.journal_wind, R.id.journal_humidity)
                    .forEach { try { setTextColor(it, quaternaryTextColor) } catch (e: Exception) { /* ignore */ } }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val height = options.outHeight
        val width = options.outWidth
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

    private fun isDarkMode(context: Context): Boolean {
        val darkModeFlag = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return darkModeFlag == Configuration.UI_MODE_NIGHT_YES
    }
}
