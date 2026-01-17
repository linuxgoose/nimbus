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
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?'
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
}
