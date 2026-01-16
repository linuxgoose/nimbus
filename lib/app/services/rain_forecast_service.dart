import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service for fetching high-resolution precipitation forecasts from Open-Meteo
/// Uses minutely (1-minute) or 15-minute data for next 6 hours
class RainForecastService {
  static final Dio _dio = Dio();

  /// Fetch minutely precipitation data for the next 6 hours
  /// Returns a map with 'time' and 'precipitation' arrays
  static Future<Map<String, dynamic>?> getMinutelyPrecipitation({
    required double lat,
    required double lon,
  }) async {
    try {
      // Try minutely endpoint first (1-minute resolution for next hour)
      final minutelyUrl =
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&minutely_15=precipitation&forecast_hours=6&timezone=auto';

      debugPrint('🌧️ Fetching rain forecast: $minutelyUrl');

      final response = await _dio.get(minutelyUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('minutely_15') &&
            data['minutely_15'] is Map<String, dynamic>) {
          final minutelyData = data['minutely_15'] as Map<String, dynamic>;

          if (minutelyData.containsKey('time') &&
              minutelyData.containsKey('precipitation')) {
            debugPrint(
              '✅ Rain forecast fetched: ${(minutelyData['time'] as List).length} data points',
            );
            return {
              'time': minutelyData['time'] as List<dynamic>,
              'precipitation': minutelyData['precipitation'] as List<dynamic>,
              'resolution': '15min',
            };
          }
        }
      }

      debugPrint('⚠️ No minutely data available, trying hourly fallback');
      return await _getHourlyFallback(lat, lon);
    } catch (e) {
      debugPrint('❌ Error fetching rain forecast: $e');
      // Try hourly fallback on error
      return await _getHourlyFallback(lat, lon);
    }
  }

  /// Fallback to hourly data if minutely is not available
  static Future<Map<String, dynamic>?> _getHourlyFallback(
    double lat,
    double lon,
  ) async {
    try {
      final hourlyUrl =
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=precipitation&forecast_hours=6&timezone=auto';

      final response = await _dio.get(hourlyUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('hourly') &&
            data['hourly'] is Map<String, dynamic>) {
          final hourlyData = data['hourly'] as Map<String, dynamic>;

          if (hourlyData.containsKey('time') &&
              hourlyData.containsKey('precipitation')) {
            debugPrint('✅ Using hourly fallback for rain forecast');
            return {
              'time': hourlyData['time'] as List<dynamic>,
              'precipitation': hourlyData['precipitation'] as List<dynamic>,
              'resolution': 'hourly',
            };
          }
        }
      }

      debugPrint('❌ Hourly fallback failed');
      return null;
    } catch (e) {
      debugPrint('❌ Error in hourly fallback: $e');
      return null;
    }
  }
}
