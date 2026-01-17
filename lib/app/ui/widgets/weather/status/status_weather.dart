import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class StatusWeather {
  /// Get icon for current weather conditions
  IconData getIconNow(
    int? weather,
    String time,
    String timeDay,
    String timeNight,
  ) =>
      _getIconBasedOnTime(weather, time, timeDay, timeNight, _getDayNightIcons);

  /// Get icon for daily forecast
  IconData getIconNowDaily(int? weather) => _getDailyIcon(weather, isDay: true);

  /// Get icon for today's forecast
  IconData getIconToday(
    int? weather,
    String time,
    String timeDay,
    String timeNight,
  ) => _getIconBasedOnTime(weather, time, timeDay, timeNight, _getTodayIcons);

  /// Get icon for 7-day forecast
  IconData getIcon7Day(int? weather) => _getDailyIcon(weather, isDay: true);

  String getText(int? weather) => _getWeatherText(weather);

  /// Get icon for notifications
  IconData getIconNotification(
    int? weather,
    String time,
    String timeDay,
    String timeNight,
  ) => _getIconBasedOnTime(
    weather,
    time,
    timeDay,
    timeNight,
    _getNotificationIcons,
  );

  /// Get image path for notifications (still needed for notification system)
  String getImageNotification(
    int? weather,
    String time,
    String timeDay,
    String timeNight,
  ) {
    final icons = _getNotificationIcons;
    final isDayTime =
        time.isNotEmpty && timeDay.isNotEmpty && timeNight.isNotEmpty
        ? time.compareTo(timeDay) >= 0 && time.compareTo(timeNight) < 0
        : true;

    // Map Lucide icons back to image asset paths for Android widgets
    final iconData = icons[weather]?[isDayTime] ?? LucideIcons.cloud;

    // Map IconData to image paths
    if (iconData == LucideIcons.sun) return 'assets/images/sun.png';
    if (iconData == LucideIcons.moon) return 'assets/images/moon.png';
    if (iconData == LucideIcons.cloudSun) return 'assets/images/cloudy_day.png';
    if (iconData == LucideIcons.cloudMoon)
      return 'assets/images/cloudy_night.png';
    if (iconData == LucideIcons.cloud) return 'assets/images/cloud.png';
    if (iconData == LucideIcons.cloudFog) return 'assets/images/fog.png';
    if (iconData == LucideIcons.cloudDrizzle) return 'assets/images/rain.png';
    if (iconData == LucideIcons.cloudRain) return 'assets/images/rain.png';
    if (iconData == LucideIcons.cloudSnow) return 'assets/images/snow.png';
    if (iconData == LucideIcons.cloudLightning)
      return 'assets/images/thunder.png';

    return 'assets/images/cloud.png'; // Default fallback
  }

  IconData _getIconBasedOnTime(
    int? weather,
    String time,
    String timeDay,
    String timeNight,
    Map<int, Map<bool, IconData>> icons,
  ) {
    final currentTime = DateTime.parse(time);
    final day = DateTime.parse(timeDay);
    final night = DateTime.parse(timeNight);

    final dayTime = DateTime(
      day.year,
      day.month,
      day.day,
      day.hour,
      day.minute,
    );
    final nightTime = DateTime(
      night.year,
      night.month,
      night.day,
      night.hour,
      night.minute,
    );

    final isDayTime =
        currentTime.isAfter(dayTime) && currentTime.isBefore(nightTime);

    return icons[weather]?[isDayTime] ?? LucideIcons.handHelping;
  }

  IconData _getDailyIcon(int? weather, {bool isDay = false}) {
    switch (weather) {
      case 0:
        return isDay ? LucideIcons.sun : LucideIcons.moon;
      case 1:
      case 2:
        return isDay ? LucideIcons.cloudSun : LucideIcons.cloudMoon;
      case 3:
        return LucideIcons.cloud;
      case 45:
      case 48:
        return LucideIcons.cloudFog;
      case 51:
      case 53:
      case 55:
        return LucideIcons.cloudDrizzle;
      case 56:
      case 57:
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return LucideIcons.cloudRain;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return LucideIcons.cloudSnow;
      case 95:
      case 96:
      case 99:
        return LucideIcons.cloudLightning;
      default:
        return LucideIcons.handHelping;
    }
  }

  String _getWeatherText(int? weather) {
    switch (weather) {
      case 0:
        return 'clear_sky'.tr;
      case 1:
      case 2:
        return 'cloudy'.tr;
      case 3:
        return 'overcast'.tr;
      case 45:
      case 48:
        return 'fog'.tr;
      case 51:
      case 53:
      case 55:
        return 'drizzle'.tr;
      case 56:
      case 57:
        return 'drizzling_rain'.tr;
      case 61:
      case 63:
      case 65:
        return 'rain'.tr;
      case 66:
      case 67:
        return 'freezing_rain'.tr;
      case 80:
      case 81:
      case 82:
        return 'heavy_rains'.tr;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'snow'.tr;
      case 95:
      case 96:
      case 99:
        return 'thunderstorm'.tr;
      default:
        return '';
    }
  }

  final Map<int, Map<bool, IconData>> _getDayNightIcons = {
    0: {true: LucideIcons.sun, false: LucideIcons.moon},
    1: {true: LucideIcons.cloudSun, false: LucideIcons.cloudMoon},
    2: {true: LucideIcons.cloudSun, false: LucideIcons.cloudMoon},
    3: {true: LucideIcons.cloud, false: LucideIcons.cloud},
    45: {true: LucideIcons.cloudFog, false: LucideIcons.cloudFog},
    48: {true: LucideIcons.cloudFog, false: LucideIcons.cloudFog},
    51: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    53: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    55: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    56: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    57: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    61: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    63: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    65: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    66: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    67: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    80: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    81: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    82: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    71: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    73: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    75: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    77: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    85: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    86: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    95: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
    96: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
    99: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
  };

  final Map<int, Map<bool, IconData>> _getTodayIcons = {
    0: {true: LucideIcons.sun, false: LucideIcons.moon},
    1: {true: LucideIcons.cloudSun, false: LucideIcons.cloudMoon},
    2: {true: LucideIcons.cloudSun, false: LucideIcons.cloudMoon},
    3: {true: LucideIcons.cloud, false: LucideIcons.cloud},
    45: {true: LucideIcons.cloudFog, false: LucideIcons.cloudFog},
    48: {true: LucideIcons.cloudFog, false: LucideIcons.cloudFog},
    51: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    53: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    55: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    56: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    57: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    61: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    63: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    65: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    66: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    67: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    80: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    81: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    82: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    71: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    73: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    75: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    77: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    85: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    86: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    95: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
    96: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
    99: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
  };

  final Map<int, Map<bool, IconData>> _getNotificationIcons = {
    0: {true: LucideIcons.sun, false: LucideIcons.moon},
    1: {true: LucideIcons.cloudSun, false: LucideIcons.cloudMoon},
    2: {true: LucideIcons.cloudSun, false: LucideIcons.cloudMoon},
    3: {true: LucideIcons.cloud, false: LucideIcons.cloud},
    45: {true: LucideIcons.cloudFog, false: LucideIcons.cloudFog},
    48: {true: LucideIcons.cloudFog, false: LucideIcons.cloudFog},
    51: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    53: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    55: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    56: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    57: {true: LucideIcons.cloudDrizzle, false: LucideIcons.cloudDrizzle},
    61: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    63: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    65: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    66: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    67: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    80: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    81: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    82: {true: LucideIcons.cloudRain, false: LucideIcons.cloudRain},
    71: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    73: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    75: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    77: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    85: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    86: {true: LucideIcons.cloudSnow, false: LucideIcons.cloudSnow},
    95: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
    96: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
    99: {true: LucideIcons.cloudLightning, false: LucideIcons.cloudLightning},
  };
}
