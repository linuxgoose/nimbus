import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nimbus/main.dart';

/// PirateWeather API service
/// Provides Dark Sky-compatible API with high-quality forecast data
/// Falls back to Open-Meteo for data not available from PirateWeather
class PirateWeatherService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Get weather data from PirateWeather API
  /// Returns data in Open-Meteo compatible format
  static Future<Map<String, dynamic>?> getWeatherData({
    required double lat,
    required double lon,
    String? apiKey,
  }) async {
    try {
      // Use stored API key or provided one
      final key = apiKey ?? settings.pirateWeatherApiKey;

      if (key == null || key.isEmpty) {
        debugPrint('⚠️ PirateWeather API key not configured');
        return null;
      }

      final url = 'https://api.pirateweather.net/forecast/$key/$lat,$lon';

      // Build query parameters
      final params = <String, dynamic>{
        'units': 'si', // Always use SI, we'll convert later
        'exclude':
            'minutely,alerts', // Exclude minutely (not needed) and alerts (use Open-Meteo)
      };

      debugPrint('🏴‍☠️ Fetching PirateWeather data for $lat, $lon');
      final response = await _dio.get(url, queryParameters: params);

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ PirateWeather data received successfully');
        return await _convertToOpenMeteoFormat(response.data, lat, lon);
      } else {
        debugPrint('❌ PirateWeather returned status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ PirateWeather error: $e');
      return null;
    }
  }

  /// Convert PirateWeather format to Open-Meteo compatible format
  static Future<Map<String, dynamic>?> _convertToOpenMeteoFormat(
    Map<String, dynamic> pirateData,
    double lat,
    double lon,
  ) async {
    try {
      debugPrint('🔄 Converting PirateWeather to Open-Meteo format');

      // Extract current data
      final currently = pirateData['currently'] as Map<String, dynamic>?;

      // Extract hourly data
      final hourlyData = pirateData['hourly'] as Map<String, dynamic>?;
      final hourlyItems = (hourlyData?['data'] as List<dynamic>?) ?? [];

      // Extract daily data
      final dailyData = pirateData['daily'] as Map<String, dynamic>?;
      final dailyItems = (dailyData?['data'] as List<dynamic>?) ?? [];

      // Build hourly arrays
      final hourlyTimes = <String>[];
      final hourlyTemps = <double?>[];
      final hourlyApparentTemps = <double?>[];
      final hourlyHumidity = <int?>[];
      final hourlyPrecip = <double?>[];
      final hourlyRain = <double?>[];
      final hourlyWeatherCodes = <int?>[];
      final hourlyPressure = <double?>[];
      final hourlyVisibility = <double?>[];
      final hourlyWindSpeed = <double?>[];
      final hourlyWindDirection = <int?>[];
      final hourlyWindGusts = <double?>[];
      final hourlyCloudCover = <int?>[];
      final hourlyUvIndex = <double?>[];
      final hourlyDewPoint = <double?>[];
      final hourlyPrecipProb = <int?>[];

      for (var hour in hourlyItems) {
        if (hour is! Map<String, dynamic>) continue;

        final time = hour['time'] as int?;
        if (time == null) continue;

        final dateTime = DateTime.fromMillisecondsSinceEpoch(
          time * 1000,
          isUtc: true,
        );
        hourlyTimes.add(dateTime.toIso8601String());

        hourlyTemps.add(_toDouble(hour['temperature']));
        hourlyApparentTemps.add(_toDouble(hour['apparentTemperature']));
        hourlyHumidity.add(
          _toInt(
            (hour['humidity'] as num?) != null
                ? (hour['humidity'] as num) * 100
                : null,
          ),
        );

        // PirateWeather provides precipitation intensity (mm/hr), convert to total mm
        final precipIntensity = _toDouble(hour['precipIntensity']);
        hourlyPrecip.add(precipIntensity);

        // If precipType is rain, use precipIntensity for rain
        final precipType = hour['precipType'] as String?;
        hourlyRain.add(precipType == 'rain' ? precipIntensity : 0.0);

        hourlyWeatherCodes.add(_darkSkyIconToWMOCode(hour['icon'] as String?));
        hourlyPressure.add(_toDouble(hour['pressure']));
        hourlyVisibility.add(_toDouble(hour['visibility']));
        hourlyWindSpeed.add(_toDouble(hour['windSpeed']));
        hourlyWindDirection.add(_toInt(hour['windBearing']));
        hourlyWindGusts.add(_toDouble(hour['windGust']));
        hourlyCloudCover.add(
          _toInt(
            (hour['cloudCover'] as num?) != null
                ? (hour['cloudCover'] as num) * 100
                : null,
          ),
        );
        hourlyUvIndex.add(_toDouble(hour['uvIndex']));
        hourlyDewPoint.add(_toDouble(hour['dewPoint']));
        hourlyPrecipProb.add(
          _toInt(
            (hour['precipProbability'] as num?) != null
                ? (hour['precipProbability'] as num) * 100
                : null,
          ),
        );
      }

      // Build daily arrays
      final dailyTimes = <String>[];
      final dailyWeatherCodes = <int?>[];
      final dailyMaxTemps = <double?>[];
      final dailyMinTemps = <double?>[];
      final dailyApparentMaxTemps = <double?>[];
      final dailyApparentMinTemps = <double?>[];
      final dailySunrise = <String>[];
      final dailySunset = <String>[];
      final dailyPrecipSum = <double?>[];
      final dailyPrecipProbMax = <int?>[];
      final dailyWindSpeedMax = <double?>[];
      final dailyWindGustMax = <double?>[];
      final dailyUvIndexMax = <double?>[];
      final dailyRainSum = <double?>[];
      final dailyWindDirectionDominant = <int?>[];

      for (var day in dailyItems) {
        if (day is! Map<String, dynamic>) continue;

        final time = day['time'] as int?;
        if (time == null) continue;

        final dateTime = DateTime.fromMillisecondsSinceEpoch(
          time * 1000,
          isUtc: true,
        );
        dailyTimes.add(dateTime.toIso8601String().split('T')[0]);

        dailyWeatherCodes.add(_darkSkyIconToWMOCode(day['icon'] as String?));
        dailyMaxTemps.add(_toDouble(day['temperatureHigh']));
        dailyMinTemps.add(_toDouble(day['temperatureLow']));
        dailyApparentMaxTemps.add(_toDouble(day['apparentTemperatureHigh']));
        dailyApparentMinTemps.add(_toDouble(day['apparentTemperatureLow']));

        final sunriseTime = day['sunriseTime'] as int?;
        final sunsetTime = day['sunsetTime'] as int?;

        if (sunriseTime != null) {
          dailySunrise.add(
            DateTime.fromMillisecondsSinceEpoch(
              sunriseTime * 1000,
              isUtc: true,
            ).toIso8601String(),
          );
        } else {
          dailySunrise.add('');
        }

        if (sunsetTime != null) {
          dailySunset.add(
            DateTime.fromMillisecondsSinceEpoch(
              sunsetTime * 1000,
              isUtc: true,
            ).toIso8601String(),
          );
        } else {
          dailySunset.add('');
        }

        // PirateWeather provides precip accumulation
        dailyPrecipSum.add(_toDouble(day['precipAccumulation']));
        dailyPrecipProbMax.add(
          _toInt(
            (day['precipProbability'] as num?) != null
                ? (day['precipProbability'] as num) * 100
                : null,
          ),
        );
        dailyWindSpeedMax.add(_toDouble(day['windSpeed']));
        dailyWindGustMax.add(_toDouble(day['windGust']));
        dailyUvIndexMax.add(_toDouble(day['uvIndex']));
        dailyRainSum.add(
          _toDouble(day['precipAccumulation']),
        ); // Assume precip is rain for now
        dailyWindDirectionDominant.add(_toInt(day['windBearing']));
      }

      // Build Open-Meteo compatible response
      final result = {
        'latitude': lat,
        'longitude': lon,
        'timezone': pirateData['timezone'] ?? 'UTC',
        'timezone_abbreviation': pirateData['timezone'] ?? 'UTC',
        'elevation': 0,
        'current_weather': currently != null
            ? {
                'time': currently['time'] != null
                    ? DateTime.fromMillisecondsSinceEpoch(
                        (currently['time'] as int) * 1000,
                        isUtc: true,
                      ).toIso8601String()
                    : DateTime.now().toUtc().toIso8601String(),
                'temperature': currently['temperature'],
                'weathercode': _darkSkyIconToWMOCode(
                  currently['icon'] as String?,
                ),
                'windspeed': currently['windSpeed'],
                'winddirection': currently['windBearing'],
              }
            : null,
        'hourly': {
          'time': hourlyTimes,
          'temperature_2m': hourlyTemps,
          'relativehumidity_2m': hourlyHumidity,
          'apparent_temperature': hourlyApparentTemps,
          'precipitation': hourlyPrecip,
          'rain': hourlyRain,
          'weathercode': hourlyWeatherCodes,
          'surface_pressure': hourlyPressure,
          'visibility': hourlyVisibility,
          'windspeed_10m': hourlyWindSpeed,
          'winddirection_10m': hourlyWindDirection,
          'windgusts_10m': hourlyWindGusts,
          'cloudcover': hourlyCloudCover,
          'uv_index': hourlyUvIndex,
          'dewpoint_2m': hourlyDewPoint,
          'precipitation_probability': hourlyPrecipProb,
          // PirateWeather doesn't provide these - will be null
          'evapotranspiration': List<double?>.filled(hourlyTimes.length, null),
          'shortwave_radiation': List<double?>.filled(hourlyTimes.length, null),
        },
        'daily': {
          'time': dailyTimes,
          'weathercode': dailyWeatherCodes,
          'temperature_2m_max': dailyMaxTemps,
          'temperature_2m_min': dailyMinTemps,
          'apparent_temperature_max': dailyApparentMaxTemps,
          'apparent_temperature_min': dailyApparentMinTemps,
          'sunrise': dailySunrise,
          'sunset': dailySunset,
          'precipitation_sum': dailyPrecipSum,
          'precipitation_probability_max': dailyPrecipProbMax,
          'windspeed_10m_max': dailyWindSpeedMax,
          'windgusts_10m_max': dailyWindGustMax,
          'uv_index_max': dailyUvIndexMax,
          'rain_sum': dailyRainSum,
          'winddirection_10m_dominant': dailyWindDirectionDominant,
        },
      };

      debugPrint('✅ PirateWeather conversion complete');
      return result;
    } catch (e) {
      debugPrint('❌ Error converting PirateWeather data: $e');
      return null;
    }
  }

  /// Convert Dark Sky icon to WMO weather code
  static int? _darkSkyIconToWMOCode(String? icon) {
    if (icon == null) return null;

    // Map Dark Sky icons to WMO codes
    // https://open-meteo.com/en/docs
    switch (icon) {
      case 'clear-day':
        return 0; // Clear sky
      case 'clear-night':
        return 0; // Clear sky
      case 'partly-cloudy-day':
        return 2; // Partly cloudy
      case 'partly-cloudy-night':
        return 2; // Partly cloudy
      case 'cloudy':
        return 3; // Overcast
      case 'fog':
        return 45; // Fog
      case 'wind':
        return 3; // Overcast (no specific wind code)
      case 'rain':
        return 61; // Rain: Moderate
      case 'sleet':
        return 67; // Freezing Rain: Moderate
      case 'snow':
        return 71; // Snow fall: Slight
      case 'thunderstorm':
        return 95; // Thunderstorm
      default:
        return null;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
