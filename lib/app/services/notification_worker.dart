import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/services/aurora_service.dart';
import 'package:nimbus/main.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
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
        final activityLevel = data['activity_level'] as String? ?? 'Active';
        await _showAuroraNotification(kpIndex, activityLevel);
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
        await _showRainNotification(totalRain);
      }
    } catch (e) {
      print('🔔 Rain: Error checking forecast - $e');
    }
  }

  static Future<void> _showAuroraNotification(
    double kpIndex,
    String activityLevel,
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

      print('🔔 Aurora: Notification sent');
    } catch (e) {
      print('🔔 Aurora: Error showing notification - $e');
    }
  }

  static Future<void> _showRainNotification(double totalRain) async {
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

      await _showWeatherAlertNotification(event, severity, description);
    } catch (e) {
      print('🔔 Weather Alerts: Error checking alerts - $e');
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
      );
    } catch (e) {
      print('🔔 Flood: Error checking warnings - $e');
    }
  }

  static Future<void> _showWeatherAlertNotification(
    String event,
    String severity,
    String description,
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

      print('🔔 Flood: Notification sent');
    } catch (e) {
      print('🔔 Flood: Error showing notification - $e');
    }
  }
}
