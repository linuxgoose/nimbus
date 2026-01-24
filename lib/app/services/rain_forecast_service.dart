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
        // Validate cached data is limited to 6 hours
        final times = cached.times ?? [];
        final precip = cached.precipitation ?? [];

        if (times.length > 1) {
          final firstTime = DateTime.parse(times.first);
          final lastTime = DateTime.parse(times.last);
          final hoursDiff = lastTime.difference(firstTime).inMinutes / 60.0;

          // If cached data exceeds 6 hours, clear it and fetch fresh data
          if (hoursDiff > 6.0) {
            debugPrint(
              '⚠️ Cached data exceeds 6 hours ($hoursDiff), clearing cache',
            );
            isar.writeTxnSync(() {
              isar.rainForecastCaches.deleteByLocationKeySync(locationKey);
            });
          } else {
            debugPrint('✅ Using cached rain forecast data ($hoursDiff hours)');
            return {
              'time': times,
              'precipitation': precip,
              'resolution': cached.resolution ?? 'unknown',
            };
          }
        }
      }
    }

    try {
      // Use minutely_15 endpoint with forecast_days=1 (gives ~24 hours, we'll filter to 6)
      String baseUrl = 'https://api.open-meteo.com';

      // Use Nimbus Meteo if selected
      if (settings.weatherDataSource == 'nimbusmeteo') {
        baseUrl = 'https://nimbusmeteo.linuxgoose.com';
      } else if (settings.useCustomOpenMeteoEndpoint &&
          settings.customOpenMeteoUrl != null &&
          settings.customOpenMeteoUrl!.isNotEmpty) {
        baseUrl = settings.customOpenMeteoUrl!;
      }

      final minutelyUrl =
          '$baseUrl/v1/forecast?latitude=$lat&longitude=$lon&minutely_15=precipitation&forecast_days=1&timezone=auto';

      debugPrint('🌧️ Fetching rain forecast: $minutelyUrl');

      final response = await _dio.get(minutelyUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('minutely_15') &&
            data['minutely_15'] is Map<String, dynamic>) {
          final minutelyData = data['minutely_15'] as Map<String, dynamic>;

          if (minutelyData.containsKey('time') &&
              minutelyData.containsKey('precipitation')) {
            final times = minutelyData['time'] as List<dynamic>;
            final precip = minutelyData['precipitation'] as List<dynamic>;

            // Filter to exactly 6 hours starting from NOW
            final List<dynamic> limitedTimes = [];
            final List<dynamic> limitedPrecip = [];
            final now = DateTime.now();

            if (times.isNotEmpty) {
              // Find the first data point that's current or in the future
              int startIndex = 0;
              for (int i = 0; i < times.length; i++) {
                final time = DateTime.parse(times[i] as String);
                if (!time.isBefore(now)) {
                  startIndex = i;
                  break;
                }
              }

              // Collect 6 hours of data from that point
              final startTime = DateTime.parse(times[startIndex] as String);
              for (int i = startIndex; i < times.length; i++) {
                final currentTime = DateTime.parse(times[i] as String);
                final hoursDiff =
                    currentTime.difference(startTime).inMinutes / 60.0;

                // Only include data points within 6 hours from start
                if (hoursDiff <= 6.0) {
                  limitedTimes.add(times[i]);
                  limitedPrecip.add(precip[i]);
                } else {
                  break;
                }
              }
            }

            debugPrint(
              '✅ Rain forecast fetched: ${limitedTimes.length} data points (${limitedTimes.first} to ${limitedTimes.last})',
            );

            final result = {
              'time': limitedTimes,
              'precipitation': limitedPrecip,
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
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=precipitation&forecast_days=1&timezone=auto';

      final response = await _dio.get(hourlyUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        if (data.containsKey('hourly') &&
            data['hourly'] is Map<String, dynamic>) {
          final hourlyData = data['hourly'] as Map<String, dynamic>;

          if (hourlyData.containsKey('time') &&
              hourlyData.containsKey('precipitation')) {
            final times = hourlyData['time'] as List<dynamic>;
            final precip = hourlyData['precipitation'] as List<dynamic>;

            // Filter to exactly 6 hours starting from NOW
            final List<dynamic> limitedTimes = [];
            final List<dynamic> limitedPrecip = [];
            final now = DateTime.now();

            if (times.isNotEmpty) {
              // Find the first data point that's current or in the future
              int startIndex = 0;
              for (int i = 0; i < times.length; i++) {
                final time = DateTime.parse(times[i] as String);
                if (!time.isBefore(now)) {
                  startIndex = i;
                  break;
                }
              }

              // Collect 6 hours of data from that point
              final startTime = DateTime.parse(times[startIndex] as String);
              for (int i = startIndex; i < times.length; i++) {
                final currentTime = DateTime.parse(times[i] as String);
                final hoursDiff =
                    currentTime.difference(startTime).inMinutes / 60.0;

                // Only include data points within 6 hours from start
                if (hoursDiff <= 6.0) {
                  limitedTimes.add(times[i]);
                  limitedPrecip.add(precip[i]);
                } else {
                  break;
                }
              }
            }

            debugPrint(
              '✅ Using hourly fallback: ${limitedTimes.length} data points (${limitedTimes.first} to ${limitedTimes.last})',
            );

            final result = {
              'time': limitedTimes,
              'precipitation': limitedPrecip,
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
