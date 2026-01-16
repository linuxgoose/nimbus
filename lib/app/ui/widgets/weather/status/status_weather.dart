import 'package:flutter/material.dart';
import 'package:get/get.dart';

const assetImageRoot = 'assets/images/';

class StatusWeather {
  String getImageNow(
    int weather,
    String time,
    String timeDay,
    String timeNight,
  ) => _getImageBasedOnTime(
    weather,
    time,
    timeDay,
    timeNight,
    _getDayNightImagePaths,
  );

  String getImageNowDaily(int? weather) => _getDailyImage(weather);

  String getImageToday(
    int weather,
    String time,
    String timeDay,
    String timeNight,
  ) => _getImageBasedOnTime(
    weather,
    time,
    timeDay,
    timeNight,
    _getTodayImagePaths,
  );

  String getImage7Day(int? weather) => _getDailyImage(weather, isDay: true);

  String getText(int? weather) => _getWeatherText(weather);

  String getImageNotification(
    int weather,
    String time,
    String timeDay,
    String timeNight,
  ) => _getImageBasedOnTime(
    weather,
    time,
    timeDay,
    timeNight,
    _getNotificationImagePaths,
  );

  String _getImageBasedOnTime(
    int weather,
    String time,
    String timeDay,
    String timeNight,
    Map<int, Map<bool, String>> imagePaths,
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

    String path = imagePaths[weather]?[isDayTime] ?? '';

    // If Dark Mode is active, try to use the white (-w) version
    if (Get.isDarkMode && path.isNotEmpty) {
      // 1. Define which icons actually have a white (-w) version
      // Add the base names of your white icons to this list
      const whiteIconsAvailable = [
        'wi-night-clear',
        'wi-sun',
        'wi-full-moon',
        'wi-moon',
        'wi-cloud',
        'wi-cloudy-day',
        'wi-day-clear',
        'wi-night-cloudy',
        'wi-night-rain',
        'wi-day-rain',
        'wi-fog',
      ];

      // 2. Check if the current path contains one of those names
      bool hasWhiteVersion = whiteIconsAvailable.any(
        (name) => path.contains(name),
      );

      if (hasWhiteVersion) {
        path = path.replaceAll('.png', '-w.png');
      }
    }

    return path;
  }

  String _getDailyImage(int? weather, {bool isDay = false}) {
    switch (weather) {
      case 0:
        return '$assetImageRoot${isDay ? 'wi-day-clear' : 'wi-sun'}.png';
      case 1:
      case 2:
      case 3:
        return '$assetImageRoot${isDay ? 'wi-cloudy-day' : 'wi-cloud'}.png';
      case 45:
      case 48:
        return '${assetImageRoot}fog${isDay ? '_day' : ''}.png';
      case 51:
      case 53:
      case 55:
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
        return '${assetImageRoot}rain${isDay ? '_day' : ''}.png';
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return '${assetImageRoot}snow${isDay ? '_day' : ''}.png';
      case 95:
      case 96:
      case 99:
        return '${assetImageRoot}thunder${isDay ? '_day' : ''}.png';
      default:
        return '';
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

  final Map<int, Map<bool, String>> _getDayNightImagePaths = {
    0: {
      true: '${assetImageRoot}wi-sun.png',
      false: '${assetImageRoot}wi-moon.png',
    },
    1: {
      true: '${assetImageRoot}wi-cloud.png',
      false: '${assetImageRoot}wi-moon.png',
    },
    2: {
      true: '${assetImageRoot}wi-cloud.png',
      false: '${assetImageRoot}wi-moon.png',
    },
    3: {
      true: '${assetImageRoot}wi-cloud.png',
      false: '${assetImageRoot}wi-moon.png',
    },
    45: {
      true: '${assetImageRoot}wi-fog.png',
      false: '${assetImageRoot}fog_moon.png',
    },
    48: {
      true: '${assetImageRoot}wi-fog.png',
      false: '${assetImageRoot}fog_moon.png',
    },
    51: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    53: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    55: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    56: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    57: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    61: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    63: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    65: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    66: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    67: {true: '${assetImageRoot}rain.png', false: '${assetImageRoot}rain.png'},
    80: {
      true: '${assetImageRoot}rain-fall.png',
      false: '${assetImageRoot}rain-fall.png',
    },
    81: {
      true: '${assetImageRoot}rain-fall.png',
      false: '${assetImageRoot}rain-fall.png',
    },
    82: {
      true: '${assetImageRoot}rain-fall.png',
      false: '${assetImageRoot}rain-fall.png',
    },
    71: {true: '${assetImageRoot}snow.png', false: '${assetImageRoot}snow.png'},
    73: {true: '${assetImageRoot}snow.png', false: '${assetImageRoot}snow.png'},
    75: {true: '${assetImageRoot}snow.png', false: '${assetImageRoot}snow.png'},
    77: {true: '${assetImageRoot}snow.png', false: '${assetImageRoot}snow.png'},
    85: {true: '${assetImageRoot}snow.png', false: '${assetImageRoot}snow.png'},
    86: {true: '${assetImageRoot}snow.png', false: '${assetImageRoot}snow.png'},
    95: {
      true: '${assetImageRoot}thunder.png',
      false: '${assetImageRoot}thunder.png',
    },
    96: {
      true: '${assetImageRoot}storm.png',
      false: '${assetImageRoot}storm.png',
    },
    99: {
      true: '${assetImageRoot}storm.png',
      false: '${assetImageRoot}storm.png',
    },
  };

  final Map<int, Map<bool, String>> _getTodayImagePaths = {
    0: {
      true: '${assetImageRoot}wi-day-clear.png',
      false: '${assetImageRoot}wi-night-clear.png',
    },
    1: {
      true: '${assetImageRoot}wi-cloudy-day.png',
      false: '${assetImageRoot}wi-night-cloudy.png',
    },
    2: {
      true: '${assetImageRoot}wi-cloudy-day.png',
      false: '${assetImageRoot}wi-night-cloudy.png',
    },
    3: {
      true: '${assetImageRoot}wi-cloudy-day.png',
      false: '${assetImageRoot}wi-night-cloudy.png',
    },
    45: {
      true: '${assetImageRoot}fog_day.png',
      false: '${assetImageRoot}fog_night.png',
    },
    48: {
      true: '${assetImageRoot}fog_day.png',
      false: '${assetImageRoot}fog_night.png',
    },
    51: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    53: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    55: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    56: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    57: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    61: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    63: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    65: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    66: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    67: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    80: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    81: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    82: {
      true: '${assetImageRoot}wi-day-rain.png',
      false: '${assetImageRoot}wi-night-rain.png',
    },
    71: {
      true: '${assetImageRoot}snow_day.png',
      false: '${assetImageRoot}snow_night.png',
    },
    73: {
      true: '${assetImageRoot}snow_day.png',
      false: '${assetImageRoot}snow_night.png',
    },
    75: {
      true: '${assetImageRoot}snow_day.png',
      false: '${assetImageRoot}snow_night.png',
    },
    77: {
      true: '${assetImageRoot}snow_day.png',
      false: '${assetImageRoot}snow_night.png',
    },
    85: {
      true: '${assetImageRoot}snow_day.png',
      false: '${assetImageRoot}snow_night.png',
    },
    86: {
      true: '${assetImageRoot}snow_day.png',
      false: '${assetImageRoot}snow_night.png',
    },
    95: {
      true: '${assetImageRoot}thunder_day.png',
      false: '${assetImageRoot}thunder_night.png',
    },
    96: {
      true: '${assetImageRoot}thunder_day.png',
      false: '${assetImageRoot}thunder_night.png',
    },
    99: {
      true: '${assetImageRoot}thunder_day.png',
      false: '${assetImageRoot}thunder_night.png',
    },
  };

  final Map<int, Map<bool, String>> _getNotificationImagePaths = {
    0: {true: 'wi-sun.png', false: 'wi-moon.png'},
    1: {true: 'wi-cloud.png', false: 'wi-moon.png'},
    2: {true: 'wi-cloud.png', false: 'wi-moon.png'},
    3: {true: 'wi-cloud.png', false: 'wi-moon.png'},
    45: {true: 'wi-fog.png', false: 'fog_moon.png'},
    48: {true: 'wi-fog.png', false: 'fog_moon.png'},
    51: {true: 'rain.png', false: 'rain.png'},
    53: {true: 'rain.png', false: 'rain.png'},
    55: {true: 'rain.png', false: 'rain.png'},
    56: {true: 'rain.png', false: 'rain.png'},
    57: {true: 'rain.png', false: 'rain.png'},
    61: {true: 'rain.png', false: 'rain.png'},
    63: {true: 'rain.png', false: 'rain.png'},
    65: {true: 'rain.png', false: 'rain.png'},
    66: {true: 'rain.png', false: 'rain.png'},
    67: {true: 'rain.png', false: 'rain.png'},
    80: {true: 'rain-fall.png', false: 'rain-fall.png'},
    81: {true: 'rain-fall.png', false: 'rain-fall.png'},
    82: {true: 'rain-fall.png', false: 'rain-fall.png'},
    71: {true: 'snow.png', false: 'snow.png'},
    73: {true: 'snow.png', false: 'snow.png'},
    75: {true: 'snow.png', false: 'snow.png'},
    77: {true: 'snow.png', false: 'snow.png'},
    85: {true: 'snow.png', false: 'snow.png'},
    86: {true: 'snow.png', false: 'snow.png'},
    95: {true: 'thunder.png', false: 'thunder.png'},
    96: {true: 'storm.png', false: 'storm.png'},
    99: {true: 'storm.png', false: 'storm.png'},
  };
}
