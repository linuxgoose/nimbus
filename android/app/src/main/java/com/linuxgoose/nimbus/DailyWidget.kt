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

class DailyWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isDarkMode = isDarkMode(context)

        for (appWidgetId in appWidgetIds) {
            val remoteViews = RemoteViews(context.packageName, R.layout.oreo_widget_daily)

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            remoteViews.setOnClickPendingIntent(R.id.widget_daily_container, pendingIntent)

            // --- ADDED: SET LOCATION NAME ---
            // This pulls the same "location_name" you saved for the hourly widget
            val locationName = widgetData.getString("location_name", "Unknown Location")
            remoteViews.setTextViewText(R.id.widget_location_name, locationName)

            // Display daily forecast data (days 0-5)
            for (i in 0 until 6) {
                val date = widgetData.getString("daily_date_$i", null)
                val max = widgetData.getString("daily_max_$i", null)
                val min = widgetData.getString("daily_min_$i", null)
                val icon = widgetData.getString("daily_icon_$i", null)
                val wind = widgetData.getString("daily_wind_$i", null)
                val precip = widgetData.getString("daily_precip_$i", null)

                android.util.Log.d("DailyWidget", "Day $i - date: $date, icon path: $icon")

                val dateViewId = context.resources.getIdentifier("daily_date_$i", "id", context.packageName)
                val maxViewId = context.resources.getIdentifier("daily_max_$i", "id", context.packageName)
                val minViewId = context.resources.getIdentifier("daily_min_$i", "id", context.packageName)
                val iconViewId = context.resources.getIdentifier("daily_icon_$i", "id", context.packageName)
                val windViewId = context.resources.getIdentifier("daily_wind_$i", "id", context.packageName)
                val precipViewId = context.resources.getIdentifier("daily_precip_$i", "id", context.packageName)

                if (date != null && max != null && min != null) {
                    remoteViews.setTextViewText(dateViewId, date)
                    remoteViews.setTextViewText(maxViewId, max)
                    remoteViews.setTextViewText(minViewId, min)
                }
                
                if (wind != null && windViewId != 0) {
                    remoteViews.setTextViewText(windViewId, wind)
                }
                
                if (precip != null && precipViewId != 0) {
                    remoteViews.setTextViewText(precipViewId, precip)
                }
                
                if (icon != null) {
                    try {
                        android.util.Log.d("DailyWidget", "Loading icon $i from: $icon")
                        val options = BitmapFactory.Options().apply {
                            inJustDecodeBounds = true
                            BitmapFactory.decodeFile(icon, this)
                            inSampleSize = calculateInSampleSize(this, 100, 100)
                            inJustDecodeBounds = false
                        }
                        val bitmap = BitmapFactory.decodeFile(icon, options)
                        if (bitmap != null) {
                            remoteViews.setImageViewBitmap(iconViewId, bitmap)
                            android.util.Log.d("DailyWidget", "Successfully loaded icon $i")
                        } else {
                            android.util.Log.e("DailyWidget", "Bitmap is null for icon $i")
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("DailyWidget", "Error loading bitmap $i", e)
                    }
                }
            }

            // --- PAPER-PASTEL BACKGROUND ---
            val backgroundColor = widgetData.getString("background_color", null)
            if (backgroundColor != null) {
                try {
                    remoteViews.setInt(R.id.widget_daily_container, "setBackgroundColor", Color.parseColor(backgroundColor))
                } catch (e: Exception) { /* ignore */ }
            } else {
                val defaultBg = if (isDarkMode) "#212121" else "#FAFBFC"
                remoteViews.setInt(R.id.widget_daily_container, "setBackgroundColor", Color.parseColor(defaultBg))
            }

            // --- PAPER-PASTEL TEXT COLORS ---
            val primaryTextColor = if (isDarkMode) Color.WHITE else Color.parseColor("#2D3436")
            val secondaryTextColor = if (isDarkMode) Color.parseColor("#D1D5DB") else Color.parseColor("#6B7280")
            val tertiaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#94A3B8")
            val quaternaryTextColor = if (isDarkMode) Color.parseColor("#9CA3AF") else Color.parseColor("#64748B")
            
            // Apply location text color
            remoteViews.setTextColor(R.id.widget_location_name, primaryTextColor)

            // Apply paper-pastel color hierarchy to all daily forecast elements
            for (i in 0 until 6) {
                val dateViewId = context.resources.getIdentifier("daily_date_$i", "id", context.packageName)
                val maxViewId = context.resources.getIdentifier("daily_max_$i", "id", context.packageName)
                val minViewId = context.resources.getIdentifier("daily_min_$i", "id", context.packageName)
                val windViewId = context.resources.getIdentifier("daily_wind_$i", "id", context.packageName)
                val precipViewId = context.resources.getIdentifier("daily_precip_$i", "id", context.packageName)
                
                if (dateViewId != 0) remoteViews.setTextColor(dateViewId, primaryTextColor)
                if (maxViewId != 0) remoteViews.setTextColor(maxViewId, primaryTextColor)
                if (minViewId != 0) remoteViews.setTextColor(minViewId, tertiaryTextColor)
                if (windViewId != 0) remoteViews.setTextColor(windViewId, quaternaryTextColor)
                if (precipViewId != 0) remoteViews.setTextColor(precipViewId, quaternaryTextColor)
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