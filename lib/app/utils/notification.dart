import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/main.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationShow {
  static const String _channelId = 'Rain';
  static const String _channelName = 'DARK NIGHT';

  Future<void> showNotification(
    int id,
    String title,
    String body,
    DateTime date,
    String icon,
  ) async {
    try {
      debugPrint(
        '🔔 NotificationShow: Scheduling notification ID $id for $date',
      );
      debugPrint('🔔   Title: $title');
      debugPrint('🔔   Body: $body');

      final scheduledTime = _getScheduledTime(date);
      debugPrint('🔔   Scheduled TZ time: $scheduledTime');

      // Try to get image, but don't fail if it doesn't work
      AndroidBitmap<Object>? largeIcon;
      try {
        final imagePath = await _getLocalImagePath(icon);
        largeIcon = FilePathAndroidBitmap(imagePath);
        debugPrint('🔔   Using icon: $imagePath');
      } catch (e) {
        debugPrint('🔔   Icon load failed (will use default): $e');
      }

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          priority: Priority.high,
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          largeIcon: largeIcon,
          icon: '@mipmap/ic_launcher',
        ),
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint(
        '✅ NotificationShow: Successfully scheduled notification ID $id',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling notification: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw so caller knows it failed
      rethrow;
    }
  }

  Future<String> _getLocalImagePath(String icon) async =>
      await WeatherController().getLocalImagePath(icon);

  tz.TZDateTime _getScheduledTime(DateTime date) =>
      tz.TZDateTime.from(date, tz.local);
}
