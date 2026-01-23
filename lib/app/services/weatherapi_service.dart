import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nimbus/main.dart';

/// WeatherAPI service
/// Converts WeatherAPI forecast into Open-Meteo compatible structure.
class WeatherApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static Future<Map<String, dynamic>?> getWeatherData({
    required double lat,
    required double lon,
    String? apiKey,
  }) async {
    final key = apiKey ?? settings.weatherApiKey;
    if (key == null || key.isEmpty) {
      debugPrint('⚠️ WeatherAPI key not configured');
      return null;
    }

    final params = {
      'key': key,
      'q': '$lat,$lon',
      'days': 10, // free tier supports up to 10 days
      'aqi': 'yes',
      'alerts': 'yes',
    };

    try {
      debugPrint('🌦️ Fetching WeatherAPI for $lat,$lon');
      final response = await _dio.get(
        'https://api.weatherapi.com/v1/forecast.json',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ WeatherAPI data received');
        return _convertToOpenMeteoFormat(response.data, lat, lon);
      }
      debugPrint('❌ WeatherAPI status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ WeatherAPI error: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _convertToOpenMeteoFormat(
    Map<String, dynamic> data,
    double lat,
    double lon,
  ) {
    try {
      final location = data['location'] as Map<String, dynamic>?;
      final current = data['current'] as Map<String, dynamic>?;
      final forecast = data['forecast'] as Map<String, dynamic>?;
      final forecastDays =
          (forecast?['forecastday'] as List<dynamic>?) ?? <dynamic>[];

      final hourlyTimes = <String>[];
      final hourlyTemps = <double?>[];
      final hourlyFeels = <double?>[];
      final hourlyHumidity = <int?>[];
      final hourlyPrecip = <double?>[];
      final hourlyRain = <double?>[];
      final hourlyCodes = <int?>[];
      final hourlyPressure = <double?>[];
      final hourlyVisibility = <double?>[];
      final hourlyWind = <double?>[];
      final hourlyWindDir = <int?>[];
      final hourlyWindGust = <double?>[];
      final hourlyCloud = <int?>[];
      final hourlyUv = <double?>[];
      final hourlyDew = <double?>[];
      final hourlyPrecipProb = <int?>[];

      final dailyTimes = <String>[];
      final dailyCodes = <int?>[];
      final dailyMaxTemps = <double?>[];
      final dailyMinTemps = <double?>[];
      final dailyFeelsMax = <double?>[];
      final dailyFeelsMin = <double?>[];
      final dailySunrise = <String>[];
      final dailySunset = <String>[];
      final dailyPrecipSum = <double?>[];
      final dailyPrecipProbMax = <int?>[];
      final dailyWindMax = <double?>[];
      final dailyWindGustMax = <double?>[];
      final dailyUvMax = <double?>[];
      final dailyRainSum = <double?>[];
      final dailyWindDirDominant = <int?>[];

      for (final day in forecastDays) {
        if (day is! Map<String, dynamic>) continue;
        final dateStr = day['date'] as String?;
        if (dateStr != null) {
          dailyTimes.add(dateStr);
        }

        final dayData = day['day'] as Map<String, dynamic>?;
        final astro = day['astro'] as Map<String, dynamic>?;

        dailyCodes.add(_mapConditionCodeToWmo(dayData?['condition']));
        dailyMaxTemps.add(_toDouble(dayData?['maxtemp_c']));
        dailyMinTemps.add(_toDouble(dayData?['mintemp_c']));
        dailyFeelsMax.add(
          _toDouble(dayData?['feelslike_c'] ?? dayData?['maxtemp_c']),
        );
        dailyFeelsMin.add(
          _toDouble(dayData?['feelslike_c'] ?? dayData?['mintemp_c']),
        );
        dailyPrecipSum.add(_toDouble(dayData?['totalprecip_mm']));

        final rainChance = _toInt(dayData?['daily_chance_of_rain']);
        final snowChance = _toInt(dayData?['daily_chance_of_snow']);
        dailyPrecipProbMax.add(_maxInt(rainChance, snowChance));
        dailyWindMax.add(_toDouble(dayData?['maxwind_kph']));
        dailyWindGustMax.add(_toDouble(dayData?['gust_kph']));
        dailyUvMax.add(_toDouble(dayData?['uv']));
        dailyRainSum.add(_toDouble(dayData?['totalprecip_mm']));
        dailyWindDirDominant.add(null);

        dailySunrise.add(_parseToIso(astro?['sunrise'] as String?, dateStr));
        dailySunset.add(_parseToIso(astro?['sunset'] as String?, dateStr));

        // Hours for this day
        final hours = (day['hour'] as List<dynamic>?) ?? [];
        for (final hour in hours) {
          if (hour is! Map<String, dynamic>) continue;
          final timeStr = hour['time'] as String?;
          if (timeStr == null) continue;
          final dt = DateTime.tryParse(timeStr)?.toUtc();
          if (dt == null) continue;
          hourlyTimes.add(dt.toIso8601String());

          hourlyTemps.add(_toDouble(hour['temp_c']));
          hourlyFeels.add(_toDouble(hour['feelslike_c']));
          hourlyHumidity.add(_toInt(hour['humidity']));
          final precip = _toDouble(hour['precip_mm']);
          hourlyPrecip.add(precip);
          hourlyRain.add(precip);
          hourlyCodes.add(_mapConditionCodeToWmo(hour['condition']));
          hourlyPressure.add(_toDouble(hour['pressure_mb']));
          hourlyVisibility.add(_toDouble(hour['vis_km']));
          hourlyWind.add(_toDouble(hour['wind_kph']));
          hourlyWindDir.add(_toInt(hour['wind_degree']));
          hourlyWindGust.add(_toDouble(hour['gust_kph']));
          hourlyCloud.add(_toInt(hour['cloud']));
          hourlyUv.add(_toDouble(hour['uv']));
          hourlyDew.add(_toDouble(hour['dewpoint_c']));
          final rainProb = _toInt(hour['chance_of_rain']);
          final snowProb = _toInt(hour['chance_of_snow']);
          hourlyPrecipProb.add(_maxInt(rainProb, snowProb));
        }
      }

      final result = {
        'latitude': lat,
        'longitude': lon,
        'timezone': location?['tz_id'] ?? 'UTC',
        'timezone_abbreviation': location?['tz_id'] ?? 'UTC',
        'elevation': 0,
        'current_weather': current == null
            ? null
            : {
                'time': _parseIso(current['last_updated']),
                'temperature': current['temp_c'],
                'weathercode': _mapConditionCodeToWmo(current['condition']),
                'windspeed': current['wind_kph'],
                'winddirection': current['wind_degree'],
              },
        'hourly': {
          'time': hourlyTimes,
          'temperature_2m': hourlyTemps,
          'relativehumidity_2m': hourlyHumidity,
          'apparent_temperature': hourlyFeels,
          'precipitation': hourlyPrecip,
          'rain': hourlyRain,
          'weathercode': hourlyCodes,
          'surface_pressure': hourlyPressure,
          'visibility': hourlyVisibility,
          'windspeed_10m': hourlyWind,
          'winddirection_10m': hourlyWindDir,
          'windgusts_10m': hourlyWindGust,
          'cloudcover': hourlyCloud,
          'uv_index': hourlyUv,
          'dewpoint_2m': hourlyDew,
          'precipitation_probability': hourlyPrecipProb,
          // Data not provided by WeatherAPI
          'evapotranspiration': List<double?>.filled(hourlyTimes.length, null),
          'shortwave_radiation': List<double?>.filled(hourlyTimes.length, null),
        },
        'daily': {
          'time': dailyTimes,
          'weathercode': dailyCodes,
          'temperature_2m_max': dailyMaxTemps,
          'temperature_2m_min': dailyMinTemps,
          'apparent_temperature_max': dailyFeelsMax,
          'apparent_temperature_min': dailyFeelsMin,
          'sunrise': dailySunrise,
          'sunset': dailySunset,
          'precipitation_sum': dailyPrecipSum,
          'precipitation_probability_max': dailyPrecipProbMax,
          'windspeed_10m_max': dailyWindMax,
          'windgusts_10m_max': dailyWindGustMax,
          'uv_index_max': dailyUvMax,
          'rain_sum': dailyRainSum,
          'winddirection_10m_dominant': dailyWindDirDominant,
        },
      };

      return result;
    } catch (e) {
      debugPrint('❌ Error converting WeatherAPI data: $e');
      return null;
    }
  }

  static String? _parseIso(dynamic value) {
    if (value == null) return null;
    final dt = DateTime.tryParse(value.toString())?.toUtc();
    return dt?.toIso8601String();
  }

  static String _parseToIso(String? time, String? date) {
    if (time == null || date == null) return '';
    // WeatherAPI returns time like "07:12 AM"
    final parsed = DateTime.tryParse('$date $time');
    return parsed?.toUtc().toIso8601String() ?? '';
  }

  static int? _mapConditionCodeToWmo(dynamic condition) {
    if (condition is Map<String, dynamic>) {
      return _mapConditionCodeToWmo(condition['code']);
    }
    if (condition is! int) return null;
    final code = condition;
    if (code == 1000) return 0; // clear
    if (code == 1003) return 2; // partly cloudy
    if (code == 1006 || code == 1009) return 3; // cloudy/overcast
    if (code == 1030 || code == 1135 || code == 1147) return 45; // fog/mist
    if (code == 1063 || code == 1150 || code == 1153 || code == 1168) return 51;
    if (code == 1171 ||
        code == 1204 ||
        code == 1207 ||
        code == 1249 ||
        code == 1252)
      return 67; // sleet/freezing
    if (code == 1066 ||
        code == 1069 ||
        code == 1072 ||
        code == 1114 ||
        code == 1117)
      return 71; // snow-ish
    if (code == 1180 ||
        code == 1183 ||
        code == 1186 ||
        code == 1189 ||
        code == 1240 ||
        code == 1243)
      return 63; // rain
    if (code == 1192 || code == 1195 || code == 1246) return 65; // heavy rain
    if (code == 1198 || code == 1201) return 66; // freezing rain
    if (code == 1210 ||
        code == 1213 ||
        code == 1216 ||
        code == 1219 ||
        code == 1222 ||
        code == 1225 ||
        code == 1255 ||
        code == 1258)
      return 75; // snow heavy
    if (code == 1237 || code == 1261 || code == 1264) return 67; // ice pellets
    if (code == 1087 ||
        code == 1273 ||
        code == 1276 ||
        code == 1279 ||
        code == 1282)
      return 95; // thunder
    return 0;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  static int? _maxInt(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }
}
