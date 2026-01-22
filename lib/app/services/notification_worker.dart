import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/services/aurora_service.dart';
import 'package:nimbus/main.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';

class NotificationWorker {
  static const String _auroraChannelId = 'aurora_alerts';
  static const String _auroraChannelName = 'Aurora Alerts';
  static const String _rainChannelId = 'rain_alerts';
  static const String _rainChannelName = 'Rain Alerts';
  static const String _weatherAlertChannelId = 'weather_alerts';
  static const String _weatherAlertChannelName = 'Weather Alerts';
  static const String _floodChannelId = 'flood_alerts';
  static const String _floodChannelName = 'Flood Alerts';

  static Future<void> checkAndNotify() async {
    print('🔔 Notification Worker: Starting background check');

    try {
      final settings = isar.settings.getSync(1);
      if (settings == null) {
        print('🔔 Notification Worker: No settings found');
        return;
      }

      // Check aurora notifications
      if (settings.auroraNotifications) {
        await _checkAuroraActivity(settings);
      }

      // Check rain notifications
      if (settings.rainNotifications) {
        await _checkRainForecast(settings);
      }

      // Check weather alert notifications
      if (settings.weatherAlertNotifications) {
        await _checkWeatherAlerts(settings);
      }

      // Check flood notifications
      if (settings.floodNotifications) {
        await _checkFloodWarnings(settings);
      }

      // Check and reschedule forecast notifications
      if (settings.notifications) {
        await _checkForecastNotifications(settings);
      }

      print('🔔 Notification Worker: Completed background check');
    } catch (e) {
      print('🔔 Notification Worker: Error - $e');
    }
  }

  static Future<void> _checkAuroraActivity(Settings settings) async {
    try {
      print('🔔 Aurora: Checking activity');

      // Get location from cache
      final allLocations = isar.locationCaches.where().findAllSync();
      if (allLocations.isEmpty) {
        print('🔔 Aurora: No location available');
        return;
      }

      final locationCache = allLocations.first;
      if (locationCache.lat == null || locationCache.lon == null) {
        print('🔔 Aurora: No location available');
        return;
      }

      final lat = locationCache.lat!;
      final lon = locationCache.lon!;

      // Get aurora data (will use cache if valid)
      final data = await AuroraService.getAuroraData(
        lat: lat,
        lon: lon,
        forceRefresh: false,
      );

      if (data == null) {
        print('🔔 Aurora: No data available');
        return;
      }

      final kpIndex = data['kp_index'] as double?;
      if (kpIndex == null) {
        print('🔔 Aurora: No Kp index in data');
        return;
      }

      print(
        '🔔 Aurora: Current Kp: $kpIndex, Threshold: ${settings.auroraNotificationThreshold}',
      );

      // Check if Kp exceeds threshold
      if (kpIndex >= settings.auroraNotificationThreshold) {
        // Check if we already sent a notification recently (within 6 hours)
        final now = DateTime.now();
        if (settings.lastAuroraNotification != null) {
          final hoursSinceLastNotification = now
              .difference(settings.lastAuroraNotification!)
              .inHours;

          // Only notify again if:
          // 1. It's been at least 6 hours, OR
          // 2. The Kp has increased by at least 1.0
          if (hoursSinceLastNotification < 6) {
            final lastKp = settings.lastNotifiedAuroraKp ?? 0;
            if (kpIndex - lastKp < 1.0) {
              print(
                '🔔 Aurora: Skipping notification (sent ${hoursSinceLastNotification}h ago, Kp change: ${kpIndex - lastKp})',
              );
              return;
            }
          }
        }

        final activityLevel = data['activity_level'] as String? ?? 'Active';
        await _showAuroraNotification(kpIndex, activityLevel, settings);
      }
    } catch (e) {
      print('🔔 Aurora: Error checking activity - $e');
    }
  }

  static Future<void> _checkRainForecast(Settings settings) async {
    try {
      print('🔔 Rain: Checking forecast');

      // Get location from cache
      final allLocations = isar.locationCaches.where().findAllSync();
      if (allLocations.isEmpty) {
        print('🔔 Rain: No location available');
        return;
      }

      final locationCache = allLocations.first;
      if (locationCache.lat == null || locationCache.lon == null) {
        print('🔔 Rain: No location available');
        return;
      }

      final lat = locationCache.lat!;
      final lon = locationCache.lon!;

      // Fetch 6-hour rain forecast from Open-Meteo
      final settingsData = await isar.settings.where().findFirst();
      String baseUrl = 'https://api.open-meteo.com';

      if (settingsData != null) {
        // Use Nimbus Meteo if selected
        if (settingsData.weatherDataSource == 'nimbusmeteo') {
          baseUrl = 'https://nimbusmeteo.linuxgoose.com';
        } else if (settingsData.useCustomOpenMeteoEndpoint &&
            settingsData.customOpenMeteoUrl != null &&
            settingsData.customOpenMeteoUrl!.isNotEmpty) {
          baseUrl = settingsData.customOpenMeteoUrl!;
        }
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/v1/forecast?'
          'latitude=$lat&longitude=$lon'
          '&hourly=precipitation'
          '&forecast_hours=6'
          '&timezone=auto',
        ),
      );

      if (response.statusCode != 200) {
        print('🔔 Rain: API request failed');
        return;
      }

      final data = json.decode(response.body);
      final hourly = data['hourly'];
      if (hourly == null) {
        print('🔔 Rain: No hourly data');
        return;
      }

      final precipitationList = hourly['precipitation'] as List?;
      if (precipitationList == null || precipitationList.isEmpty) {
        print('🔔 Rain: No precipitation data');
        return;
      }

      // Calculate total rain in next 6 hours
      double totalRain = 0;
      for (var value in precipitationList) {
        if (value != null) {
          totalRain += (value as num).toDouble();
        }
      }

      print(
        '🔔 Rain: Total in next 6h: ${totalRain.toStringAsFixed(1)}mm, Threshold: ${settings.rainNotificationThreshold}mm',
      );

      // Check if rain exceeds threshold
      if (totalRain >= settings.rainNotificationThreshold) {
        // Check if we already sent a notification recently (within 3 hours)
        final now = DateTime.now();
        if (settings.lastRainNotification != null) {
          final hoursSinceLastNotification = now
              .difference(settings.lastRainNotification!)
              .inHours;

          if (hoursSinceLastNotification < 3) {
            print(
              '🔔 Rain: Skipping notification (sent ${hoursSinceLastNotification}h ago)',
            );
            return;
          }
        }

        await _showRainNotification(totalRain, settings);
      }
    } catch (e) {
      print('🔔 Rain: Error checking forecast - $e');
    }
  }

  static Future<void> _showAuroraNotification(
    double kpIndex,
    String activityLevel,
    Settings settings,
  ) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _auroraChannelId,
        _auroraChannelName,
        channelDescription: 'Notifications for aurora activity',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        1, // Aurora notification ID
        '✨ Aurora Alert',
        '$activityLevel aurora activity detected! Kp index: ${kpIndex.toStringAsFixed(1)}',
        notificationDetails,
      );

      // Update tracking
      isar.writeTxnSync(() {
        settings.lastAuroraNotification = DateTime.now();
        settings.lastNotifiedAuroraKp = kpIndex;
        isar.settings.putSync(settings);
      });

      print('🔔 Aurora: Notification sent');
    } catch (e) {
      print('🔔 Aurora: Error showing notification - $e');
    }
  }

  static Future<void> _showRainNotification(
    double totalRain,
    Settings settings,
  ) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _rainChannelId,
        _rainChannelName,
        channelDescription: 'Notifications for upcoming rain',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        2, // Rain notification ID
        '🌧️ Rain Alert',
        'Rain expected in the next 6 hours: ${totalRain.toStringAsFixed(1)}mm',
        notificationDetails,
      );

      // Update tracking
      isar.writeTxnSync(() {
        settings.lastRainNotification = DateTime.now();
        isar.settings.putSync(settings);
      });

      print('🔔 Rain: Notification sent');
    } catch (e) {
      print('🔔 Rain: Error showing notification - $e');
    }
  }

  static Future<void> _checkWeatherAlerts(Settings settings) async {
    try {
      print('🔔 Weather Alerts: Checking for active alerts');

      // Get location from cache
      final allLocations = isar.locationCaches.where().findAllSync();
      if (allLocations.isEmpty) {
        print('🔔 Weather Alerts: No location available');
        return;
      }

      final locationCache = allLocations.first;
      if (locationCache.lat == null || locationCache.lon == null) {
        print('🔔 Weather Alerts: No location available');
        return;
      }

      final lat = locationCache.lat!;
      final lon = locationCache.lon!;

      // Fetch weather data with alerts from API
      String baseUrl = 'https://api.open-meteo.com';

      if (settings.weatherDataSource == 'nimbusmeteo') {
        baseUrl = 'https://nimbusmeteo.linuxgoose.com';
      } else if (settings.useCustomOpenMeteoEndpoint &&
          settings.customOpenMeteoUrl != null &&
          settings.customOpenMeteoUrl!.isNotEmpty) {
        baseUrl = settings.customOpenMeteoUrl!;
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/v1/forecast?'
          'latitude=$lat&longitude=$lon'
          '&alerts=true'
          '&timezone=auto',
        ),
      );

      if (response.statusCode != 200) {
        print('🔔 Weather Alerts: API request failed');
        return;
      }

      final data = json.decode(response.body);
      final alerts = data['alerts'] as List?;

      if (alerts == null || alerts.isEmpty) {
        print('🔔 Weather Alerts: No active alerts');
        return;
      }

      // Filter alerts by minimum severity
      final filteredAlerts = alerts.where((alert) {
        final severity =
            (alert['severity'] as String?)?.toLowerCase() ?? 'unknown';

        switch (settings.weatherAlertMinSeverity) {
          case 'extreme':
            return severity == 'extreme';
          case 'severe':
            return severity == 'extreme' || severity == 'severe';
          case 'moderate':
            return severity == 'extreme' ||
                severity == 'severe' ||
                severity == 'moderate';
          default:
            return true;
        }
      }).toList();

      if (filteredAlerts.isEmpty) {
        print('🔔 Weather Alerts: No alerts matching severity threshold');
        return;
      }

      print('🔔 Weather Alerts: Found ${filteredAlerts.length} alert(s)');

      // Send notification for the most severe alert
      final firstAlert = filteredAlerts.first;
      final event = firstAlert['event'] as String? ?? 'Weather Alert';
      final severity = firstAlert['severity'] as String? ?? 'Unknown';
      final description = firstAlert['description'] as String? ?? '';

      // Create a simple ID from event name for tracking
      final alertId = '${event}_$severity';

      // Check if we already sent a notification for this alert recently (within 12 hours)
      final now = DateTime.now();
      if (settings.lastWeatherAlertNotification != null &&
          settings.lastNotifiedWeatherAlertId == alertId) {
        final hoursSinceLastNotification = now
            .difference(settings.lastWeatherAlertNotification!)
            .inHours;

        if (hoursSinceLastNotification < 12) {
          print(
            '🔔 Weather Alerts: Skipping notification for "$event" (sent ${hoursSinceLastNotification}h ago)',
          );
          return;
        }
      }

      await _showWeatherAlertNotification(
        event,
        severity,
        description,
        alertId,
        settings,
      );
    } catch (e) {
      print('🔔 Weather Alerts: Error checking alerts - $e');
    }
  }

  static Future<void> _checkForecastNotifications(Settings settings) async {
    try {
      print('🔔 Forecast: Checking scheduled notifications');

      // Check if there are pending forecast notifications
      final pendingNotificationRequests = await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();

      // If no pending forecast notifications, reschedule them
      if (pendingNotificationRequests.isEmpty) {
        print('🔔 Forecast: No pending notifications found, rescheduling...');

        // Get weather data from cache
        final allLocations = isar.locationCaches.where().findAllSync();
        if (allLocations.isEmpty) {
          print('🔔 Forecast: No location available');
          return;
        }

        final locationCache = allLocations.first;
        final lat = locationCache.lat;
        final lon = locationCache.lon;

        if (lat == null || lon == null) {
          print('🔔 Forecast: No location coordinates');
          return;
        }

        // Get cached weather data (there's only one MainWeatherCache)
        final weatherCache = isar.mainWeatherCaches.where().findFirstSync();

        if (weatherCache == null) {
          print('🔔 Forecast: No weather cache available');
          return;
        }

        // Schedule forecast notifications using the weather controller logic
        await _scheduleForecastNotifications(weatherCache, settings);
        print('🔔 Forecast: Successfully rescheduled notifications');
      } else {
        print(
          '🔔 Forecast: ${pendingNotificationRequests.length} notifications already scheduled',
        );
      }
    } catch (e) {
      print('🔔 Forecast: Error - $e');
    }
  }

  static Future<void> _checkFloodWarnings(Settings settings) async {
    try {
      print('🔔 Flood: Checking for flood warnings');

      // Get location from cache
      final allLocations = isar.locationCaches.where().findAllSync();
      if (allLocations.isEmpty) {
        print('🔔 Flood: No location available');
        return;
      }

      final locationCache = allLocations.first;
      if (locationCache.lat == null || locationCache.lon == null) {
        print('🔔 Flood: No location available');
        return;
      }

      final lat = locationCache.lat!;
      final lon = locationCache.lon!;

      // Fetch flood warnings from UK Environment Agency API
      final response = await http.get(
        Uri.parse(
          'https://environment.data.gov.uk/flood-monitoring/id/floods?'
          'lat=$lat&long=$lon&dist=${settings.floodRadiusKm}',
        ),
      );

      if (response.statusCode != 200) {
        print('🔔 Flood: API request failed');
        return;
      }

      final data = json.decode(response.body);
      final items = data['items'] as List?;

      if (items == null || items.isEmpty) {
        print('🔔 Flood: No flood warnings in area');
        return;
      }

      print('🔔 Flood: Found ${items.length} flood warning(s)');

      // Check if we already sent a notification recently (within 6 hours)
      final now = DateTime.now();
      if (settings.lastFloodNotification != null) {
        final hoursSinceLastNotification = now
            .difference(settings.lastFloodNotification!)
            .inHours;

        if (hoursSinceLastNotification < 6) {
          print(
            '🔔 Flood: Skipping notification (sent ${hoursSinceLastNotification}h ago)',
          );
          return;
        }
      }

      // Send notification for the first/most relevant warning
      final firstWarning = items.first;
      final severity = firstWarning['severity'] as String? ?? 'Unknown';
      final severityLevel = firstWarning['severityLevel'] as int? ?? 1;
      final description =
          firstWarning['description'] as String? ??
          'Flood warning in your area';
      final areaName =
          firstWarning['floodArea']?['riverOrSea'] as String? ?? 'your area';

      await _showFloodNotification(
        severity,
        severityLevel,
        areaName,
        description,
        settings,
      );
    } catch (e) {
      print('🔔 Flood: Error checking warnings - $e');
    }
  }

  static Future<void> _showWeatherAlertNotification(
    String event,
    String severity,
    String description,
    String alertId,
    Settings settings,
  ) async {
    try {
      // Determine emoji based on severity
      String emoji = '⚠️';
      Importance importance = Importance.high;
      Priority priority = Priority.high;

      switch (severity.toLowerCase()) {
        case 'extreme':
          emoji = '🚨';
          importance = Importance.max;
          priority = Priority.max;
          break;
        case 'severe':
          emoji = '⛔';
          importance = Importance.high;
          priority = Priority.high;
          break;
        case 'moderate':
          emoji = '⚠️';
          importance = Importance.defaultImportance;
          priority = Priority.defaultPriority;
          break;
      }

      final androidDetails = AndroidNotificationDetails(
        _weatherAlertChannelId,
        _weatherAlertChannelName,
        channelDescription: 'Notifications for severe weather alerts',
        importance: importance,
        priority: priority,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      // Truncate description if too long
      String notificationBody = event;
      if (description.isNotEmpty && description.length < 100) {
        notificationBody += '\n$description';
      }

      await flutterLocalNotificationsPlugin.show(
        3, // Weather alert notification ID
        '$emoji $severity Weather Alert',
        notificationBody,
        notificationDetails,
      );

      // Update tracking
      isar.writeTxnSync(() {
        settings.lastWeatherAlertNotification = DateTime.now();
        settings.lastNotifiedWeatherAlertId = alertId;
        isar.settings.putSync(settings);
      });

      print('🔔 Weather Alerts: Notification sent');
    } catch (e) {
      print('🔔 Weather Alerts: Error showing notification - $e');
    }
  }

  static Future<void> _showFloodNotification(
    String severity,
    int severityLevel,
    String areaName,
    String description,
    Settings settings,
  ) async {
    try {
      // Determine importance based on severity level
      Importance importance = Importance.high;
      Priority priority = Priority.high;

      if (severityLevel >= 3) {
        importance = Importance.max;
        priority = Priority.max;
      }

      final androidDetails = AndroidNotificationDetails(
        _floodChannelId,
        _floodChannelName,
        channelDescription: 'Notifications for flood warnings',
        importance: importance,
        priority: priority,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        4, // Flood notification ID
        '🌊 Flood Warning',
        '$severity alert for $areaName',
        notificationDetails,
      );

      // Save to Alert History
      final locationCache = isar.locationCaches.where().findFirstSync();
      if (locationCache != null &&
          locationCache.lat != null &&
          locationCache.lon != null) {
        final alert = AlertHistory(
          lat: locationCache.lat!,
          lon: locationCache.lon!,
          timestamp: DateTime.now(),
          event: 'Flood Warning',
          severity: severity,
          description: '$severity flood warning for $areaName. $description',
          eventKey:
              '${locationCache.lat}_${locationCache.lon}_${DateTime.now().millisecondsSinceEpoch}_flood',
        );

        isar.writeTxnSync(() {
          isar.alertHistorys.putSync(alert);
          settings.lastFloodNotification = DateTime.now();
          isar.settings.putSync(settings);
        });
      } else {
        // Fallback if no location cache (shouldn't happen if we are here)
        isar.writeTxnSync(() {
          settings.lastFloodNotification = DateTime.now();
          isar.settings.putSync(settings);
        });
      }

      print('🔔 Flood: Notification sent & saved to history');
    } catch (e) {
      print('🔔 Flood: Error showing notification - $e');
    }
  }

  static Future<void> _scheduleForecastNotifications(
    MainWeatherCache mainWeatherCache,
    Settings settings,
  ) async {
    try {
      print('🔔 Forecast: Starting to schedule notifications');
      final now = DateTime.now();
      final timeRange = settings.timeRange;
      final timeStart = settings.timeStart;
      final timeEnd = settings.timeEnd;

      print(
        '🔔 Forecast: Settings - timeRange=$timeRange, timeStart=$timeStart, timeEnd=$timeEnd',
      );

      // Parse start and end hours
      final startParts = (timeStart ?? '00:00').split(':');
      final endParts = (timeEnd ?? '23:59').split(':');
      final startHour = int.parse(startParts[0]);
      final endHour = int.parse(endParts[0]);

      print(
        '🔔 Forecast: Allowed hours: $startHour to $endHour, Current hour: ${now.hour}',
      );

      // Check if we're in quiet hours
      final currentHour = now.hour;
      bool isInQuietHours;
      if (startHour > endHour) {
        // Spans midnight
        isInQuietHours = currentHour >= startHour || currentHour < endHour;
      } else {
        isInQuietHours = currentHour >= startHour && currentHour < endHour;
      }

      if (isInQuietHours) {
        print('🔕 Forecast: Currently in quiet hours, skipping schedule');
        return;
      }

      final timeList = mainWeatherCache.time ?? [];
      print('🔔 Forecast: Found ${timeList.length} time slots in cache');

      int scheduledCount = 0;
      int skippedCount = 0;
      final range = timeRange ?? 1;

      for (var i = 0; i < timeList.length; i += range) {
        final timeStr = timeList[i];
        final notificationTime = DateTime.parse(timeStr);

        if (notificationTime.isAfter(now) &&
            notificationTime.hour >= startHour &&
            notificationTime.hour <= endHour) {
          final dailyTime = mainWeatherCache.timeDaily ?? [];
          for (var j = 0; j < dailyTime.length; j++) {
            if (dailyTime[j].day == notificationTime.day) {
              final temp = mainWeatherCache.temperature2M?[i];
              final feelsLike = mainWeatherCache.apparentTemperature?[i];
              final humidity = mainWeatherCache.relativehumidity2M?[i];
              final windSpeed = mainWeatherCache.windspeed10M?[i];
              final precipitation =
                  mainWeatherCache.precipitationProbability?[i];
              final weatherCode = mainWeatherCache.weathercode?[i] ?? 0;

              // Get location name
              final allLocations = isar.locationCaches.where().findAllSync();
              final city = allLocations.isNotEmpty
                  ? (allLocations.first.city ?? 'Weather')
                  : 'Weather';

              // Build notification body
              String body = _getWeatherDescription(weatherCode);
              if (feelsLike != null) {
                body += ' · Feels like ${feelsLike.toStringAsFixed(0)}°';
              }
              if (humidity != null) {
                body += ' · ${humidity.toStringAsFixed(0)}% humidity';
              }
              if (windSpeed != null) {
                body += ' · ${windSpeed.toStringAsFixed(0)} mph wind';
              }
              if (precipitation != null && precipitation > 0) {
                body += ' · ${precipitation.toStringAsFixed(0)}% rain';
              }

              final notificationId =
                  notificationTime.millisecondsSinceEpoch ~/ 1000;
              print(
                '🔔 Forecast: Scheduling notification ID $notificationId for $notificationTime',
              );
              print(
                '🔔 Forecast: Title: "$city: ${temp?.toStringAsFixed(0) ?? 0}°"',
              );
              print('🔔 Forecast: Body: "$body"');

              // Schedule notification using the correct channel ID 'Rain'
              await flutterLocalNotificationsPlugin.zonedSchedule(
                notificationId,
                '$city: ${temp?.toStringAsFixed(0) ?? 0}°',
                body,
                _convertToTZDateTime(notificationTime),
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'Rain', // Use the same channel ID as in main.dart
                    'DARK NIGHT',
                    channelDescription: 'Weather forecast notifications',
                    importance: Importance.max,
                    priority: Priority.high,
                    playSound: false,
                    enableVibration: false,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              );
              scheduledCount++;
              print('✅ Forecast: Successfully scheduled for $notificationTime');
              break;
            }
          }
        } else {
          skippedCount++;
        }
      }

      print(
        '🔔 Forecast: Scheduled $scheduledCount notifications (skipped $skippedCount)',
      );

      // Verify scheduled notifications
      final pending = await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      print(
        '🔔 Forecast: Total pending notifications in system: ${pending.length}',
      );
    } catch (e, stackTrace) {
      print('🔔 Forecast: Error scheduling - $e');
      print('🔔 Forecast: Stack trace: $stackTrace');
    }
  }

  static String _getWeatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 57) return 'Drizzle';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Showers';
    if (code <= 86) return 'Snow showers';
    return 'Thunderstorm';
  }

  static tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }
}
