import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';

/// Service for fetching high-resolution precipitation forecasts from Open-Meteo
/// Uses minutely (1-minute) or 15-minute data for next 6 hours
class RainForecastService {
  static final Dio _dio = Dio();

  /// Fetch minutely precipitation data for the next 6 hours
  /// Returns a map with 'time' and 'precipitation' arrays
  /// Uses cache if available and not expired
  static Future<Map<String, dynamic>?> getMinutelyPrecipitation({
    required double lat,
    required double lon,
  }) async {
    // Generate location key for cache lookup
    final locationKey = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}';

    // Check cache first
    final cached = isar.rainForecastCaches.getByLocationKeySync(locationKey);

    if (cached != null && cached.expiresAt != null) {
      if (DateTime.now().isBefore(cached.expiresAt!)) {
        debugPrint('✅ Using cached rain forecast data');
        return {
          'time': cached.times ?? [],
          'precipitation': cached.precipitation ?? [],
          'resolution': cached.resolution ?? 'unknown',
        };
      }
    }

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

            final result = {
              'time': minutelyData['time'] as List<dynamic>,
              'precipitation': minutelyData['precipitation'] as List<dynamic>,
              'resolution': '15min',
            };

            // Cache the result
            _cacheRainForecast(locationKey, lat, lon, result);

            return result;
          }
        }
      }

      debugPrint('⚠️ No minutely data available, trying hourly fallback');
      return await _getHourlyFallback(lat, lon, locationKey);
    } catch (e) {
      debugPrint('❌ Error fetching rain forecast: $e');
      // If we have expired cache, return it as fallback
      if (cached != null) {
        debugPrint('⚠️ Using expired cache as fallback');
        return {
          'time': cached.times ?? [],
          'precipitation': cached.precipitation ?? [],
          'resolution': cached.resolution ?? 'unknown',
        };
      }
      // Try hourly fallback on error
      return await _getHourlyFallback(lat, lon, locationKey);
    }
  }

  /// Cache rain forecast data
  static void _cacheRainForecast(
    String locationKey,
    double lat,
    double lon,
    Map<String, dynamic> data,
  ) {
    try {
      final times = (data['time'] as List).map((t) => t.toString()).toList();
      final precipitation = (data['precipitation'] as List)
          .map((p) => (p as num?)?.toDouble())
          .toList();
      final resolution = data['resolution'] as String;

      final cache = RainForecastCache(
        locationKey: locationKey,
        lat: lat,
        lon: lon,
        times: times,
        precipitation: precipitation,
        resolution: resolution,
        cachedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );

      isar.writeTxnSync(() {
        isar.rainForecastCaches.putByLocationKeySync(cache);
      });

      debugPrint('💾 Rain forecast cached for $locationKey');
    } catch (e) {
      debugPrint('❌ Error caching rain forecast: $e');
    }
  }

  /// Fallback to hourly data if minutely is not available
  static Future<Map<String, dynamic>?> _getHourlyFallback(
    double lat,
    double lon,
    String locationKey,
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

            final result = {
              'time': hourlyData['time'] as List<dynamic>,
              'precipitation': hourlyData['precipitation'] as List<dynamic>,
              'resolution': 'hourly',
            };

            // Cache the result
            _cacheRainForecast(locationKey, lat, lon, result);

            return result;
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
