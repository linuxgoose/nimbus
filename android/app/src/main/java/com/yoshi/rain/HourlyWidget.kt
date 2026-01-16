package com.yoshi.rain

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.BitmapFactory
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HourlyWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isDarkMode = isDarkMode(context)

        for (appWidgetId in appWidgetIds) {
            val remoteViews = RemoteViews(context.packageName, R.layout.oreo_widget_hourly)

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            remoteViews.setOnClickPendingIntent(R.id.widget_hourly_container, pendingIntent)

            // --- SET LOCATION NAME ---
            val locationName = widgetData.getString("location_name", "Unknown Location")
            remoteViews.setTextViewText(R.id.widget_location_name, locationName)

            // --- DARK MODE THEME COLORS ---
            val textColor = widgetData.getString("text_color", null)
            val finalTextColor = if (textColor != null) {
                try { Color.parseColor(textColor) } catch (e: Exception) { 
                    if (isDarkMode) Color.WHITE else Color.BLACK 
                }
            } else {
                if (isDarkMode) Color.WHITE else Color.BLACK
            }

            val backgroundColor = widgetData.getString("background_color", null)
            val finalBgColor = if (backgroundColor != null) {
                try { Color.parseColor(backgroundColor) } catch (e: Exception) {
                    Color.parseColor(if (isDarkMode) "#212121" else "#FFFFFF")
                }
            } else {
                Color.parseColor(if (isDarkMode) "#212121" else "#FFFFFF")
            }

            // Apply global colors
            remoteViews.setInt(R.id.widget_hourly_container, "setBackgroundColor", finalBgColor)
            remoteViews.setTextColor(R.id.widget_location_name, finalTextColor)

            // --- HOURLY FORECAST LOOP (0-5) ---
            for (i in 0 until 6) {
                val time = widgetData.getString("hourly_time_$i", null)
                val temp = widgetData.getString("hourly_temp_$i", null)
                val wind = widgetData.getString("hourly_wind_$i", null) // Wind data
                val icon = widgetData.getString("hourly_icon_$i", null)

                val timeViewId = context.resources.getIdentifier("hourly_time_$i", "id", context.packageName)
                val tempViewId = context.resources.getIdentifier("hourly_temp_$i", "id", context.packageName)
                val windViewId = context.resources.getIdentifier("hourly_wind_$i", "id", context.packageName)
                val iconViewId = context.resources.getIdentifier("hourly_icon_$i", "id", context.packageName)

                // Set Text Values
                if (time != null) remoteViews.setTextViewText(timeViewId, time)
                if (temp != null) remoteViews.setTextViewText(tempViewId, temp)
                if (wind != null && windViewId != 0) remoteViews.setTextViewText(windViewId, wind)

                // Apply Text Colors
                if (timeViewId != 0) remoteViews.setTextColor(timeViewId, finalTextColor)
                if (tempViewId != 0) remoteViews.setTextColor(tempViewId, finalTextColor)
                if (windViewId != 0) remoteViews.setTextColor(windViewId, finalTextColor)

                // Handle Icon with Memory Protection (Downsampling)
                if (icon != null) {
                    try {
                        val options = BitmapFactory.Options().apply {
                            inJustDecodeBounds = true // Check dimensions first
                            BitmapFactory.decodeFile(icon, this)
                            inSampleSize = calculateInSampleSize(this, 100, 100)
                            inJustDecodeBounds = false
                        }
                        val bitmap = BitmapFactory.decodeFile(icon, options)
                        if (bitmap != null) {
                            remoteViews.setImageViewBitmap(iconViewId, bitmap)
                        }
                    } catch (e: Exception) {
                        Log.e("HourlyWidget", "Error loading icon $i", e)
                    }
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, remoteViews)
        }
    }

    private fun calculateInSampleSize(options: BitmapFactory.Options, reqWidth: Int, reqHeight: Int): Int {
        val (height: Int, width: Int) = options.outHeight to options.outWidth
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