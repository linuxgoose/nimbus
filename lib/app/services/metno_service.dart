import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for interacting with MET Norway Weather API
/// API Documentation: https://api.met.no/
class MetNoService {
  static const String _baseUrl = 'https://api.met.no/weatherapi';
  static const String _userAgent = 'Nimbus Weather App github.com/linuxgoose/nimbus';

  /// Get location forecast from MET Norway
  /// Uses the compact format for efficiency
  /// https://api.met.no/weatherapi/locationforecast/2.0/documentation
  static Future<Map<String, dynamic>?> getLocationForecast({
    required double lat,
    required double lon,
    int? altitude,
  }) async {
    try {
      final altitudeParam = altitude != null ? '&altitude=$altitude' : '';
      final url = Uri.parse(
        '$_baseUrl/locationforecast/2.0/compact?lat=$lat&lon=$lon$altitudeParam',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 203) {
        // 203 means deprecated version, but still works
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ MET Norway API Error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MET Norway API Exception: $e');
      return null;
    }
  }

  /// Get Nowcast (short-term precipitation forecast for Nordic area)
  /// Updates every 5 minutes, 2-hour forecast
  /// https://api.met.no/weatherapi/nowcast/2.0/documentation
  static Future<Map<String, dynamic>?> getNowcast({
    required double lat,
    required double lon,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/nowcast/2.0/complete?lat=$lat&lon=$lon',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 204) {
        // 204 means location outside Nordic area
        debugPrint('ℹ️ MET Nowcast: Location outside coverage area');
        return null;
      } else {
        debugPrint('❌ MET Nowcast API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MET Nowcast API Exception: $e');
      return null;
    }
  }

  /// Get weather alerts from MetAlerts API
  /// Official weather warnings for Norway and Nordic region
  /// https://api.met.no/weatherapi/metalerts/2.0/documentation
  static Future<Map<String, dynamic>?> getMetAlerts({
    required double lat,
    required double lon,
  }) async {
    try {
      // MetAlerts API - fetch all alerts for the region
      // We'll filter by location in the response
      final url = Uri.parse('$_baseUrl/metalerts/2.0/current.json');

      debugPrint('🔍 MetAlerts URL: $url');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/geo+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ MetAlerts response received');
        return data;
      } else {
        debugPrint('❌ MET Alerts API Error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MET Alerts API Exception: $e');
      return null;
    }
  }

  /// Get sunrise/sunset times
  /// https://api.met.no/weatherapi/sunrise/3.0/documentation
  static Future<Map<String, dynamic>?> getSunrise({
    required double lat,
    required double lon,
    required DateTime date,
    int days = 1, // This parameter is kept for API compatibility but not used
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      // Note: 'days' parameter is NOT supported by MET Norway Sunrise API
      final url = Uri.parse(
        '$_baseUrl/sunrise/3.0/sun?lat=$lat&lon=$lon&date=$dateStr',
      );

      debugPrint('🌅 Calling MET Sunrise API: $url');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ MET Sunrise API Success for $dateStr');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ MET Sunrise API Error: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MET Sunrise API Exception: $e');
      return null;
    }
  }

  /// Get radar images for Nordic area
  /// https://api.met.no/weatherapi/radar/2.0/documentation
  static Future<List<String>?> getRadarImages({
    String area = 'nordic',
    String type = 'precipitation',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/radar/2.0/available.json?area=$area&type=$type',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final available = data['available'] as List<dynamic>?;
        return available?.map((e) => e.toString()).toList();
      } else {
        debugPrint('❌ MET Radar API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MET Radar API Exception: $e');
      return null;
    }
  }

  /// Calculate dewpoint temperature using Magnus formula
  /// https://en.wikipedia.org/wiki/Dew_point
  static double _calculateDewpoint(double tempC, double relativeHumidity) {
    if (relativeHumidity <= 0) return tempC;
    
    const double a = 17.27;
    const double b = 237.7;
    
    final alpha = ((a * tempC) / (b + tempC)) + log(relativeHumidity / 100.0);
    final dewpoint = (b * alpha) / (a - alpha);
    
    return dewpoint;
  }

  /// Convert MET Norway symbol code to WMO weather code
  /// https://api.met.no/weatherapi/weathericon/2.0/documentation
  static int _convertSymbolToWeatherCode(String? symbolCode) {
    if (symbolCode == null) return 0;

    // Remove day/night/polar variants
    final code = symbolCode.replaceAll(RegExp(r'_(day|night|polartwilight)$'), '');

    switch (code) {
      case 'clearsky':
        return 0; // Clear sky
      case 'fair':
        return 1; // Mainly clear
      case 'partlycloudy':
        return 2; // Partly cloudy
      case 'cloudy':
        return 3; // Overcast
      case 'fog':
        return 45; // Fog
      case 'lightrainshowers':
      case 'lightrain':
        return 51; // Light drizzle
      case 'rainshowers':
      case 'rain':
        return 61; // Moderate rain
      case 'heavyrainshowers':
      case 'heavyrain':
        return 65; // Heavy rain
      case 'lightsleetshowers':
      case 'lightsleet':
        return 68; // Light sleet
      case 'sleetshowers':
      case 'sleet':
        return 69; // Moderate sleet
      case 'lightsnowshowers':
      case 'lightsnow':
        return 71; // Light snow
      case 'snowshowers':
      case 'snow':
        return 73; // Moderate snow
      case 'heavysnowshowers':
      case 'heavysnow':
        return 75; // Heavy snow
      case 'rainandthunder':
      case 'lightrainandthunder':
        return 95; // Thunderstorm
      case 'heavyrainandthunder':
        return 96; // Thunderstorm with heavy rain
      case 'sleetandthunder':
        return 95; // Thunderstorm
      case 'snowandthunder':
        return 95; // Thunderstorm
      default:
        return 0;
    }
  }

  /// Convert MET Norway forecast to Open-Meteo format
  /// This allows using MET Norway data with existing app logic
  static Future<Map<String, dynamic>?> convertToOpenMeteoFormat(
    Map<String, dynamic>? metnoData, {
    double? lat,
    double? lon,
  }) async {
    if (metnoData == null) {
      debugPrint('⚠️ MET Norway data is null');
      return null;
    }

    try {
      final properties = metnoData['properties'];
      if (properties == null || properties is! Map<String, dynamic>) {
        debugPrint('❌ Invalid properties structure in MET Norway response');
        return null;
      }
      
      final timeseries = properties['timeseries'];
      if (timeseries == null || timeseries is! List || timeseries.isEmpty) {
        debugPrint('❌ No timeseries data in MET Norway response');
        return null;
      }

      final times = <String>[];
      final temps = <double>[];
      final precipitation = <double>[];
      final weatherCodes = <int>[];
      final windSpeed = <double>[];
      final windDirection = <double>[];
      final windGusts = <double>[];
      final humidity = <int>[];
      final pressure = <double>[];
      final cloudCover = <int>[];
      final visibility = <double>[];
      final dewpoint = <double>[];
      final uvIndex = <double>[];

      for (var entry in timeseries) {
        if (entry == null || entry is! Map<String, dynamic>) {
          debugPrint('⚠️ Skipping invalid timeseries entry');
          continue;
        }
        
        final time = entry['time'];
        if (time == null || time is! String) continue;
        
        final data = entry['data'];
        if (data == null || data is! Map<String, dynamic>) continue;
        
        final instant = data['instant'];
        if (instant == null || instant is! Map<String, dynamic>) continue;
        
        final details = instant['details'];
        if (details == null || details is! Map<String, dynamic>) continue;

        times.add(time);
        final temp = (details['air_temperature'] as num?)?.toDouble() ?? 0.0;
        final speed = (details['wind_speed'] as num?)?.toDouble() ?? 0.0;
        final direction = (details['wind_from_direction'] as num?)?.toDouble() ?? 0.0;
        
        temps.add(temp);
        windSpeed.add(speed);
        windDirection.add(direction);
        
        // MET Norway doesn't provide wind gusts, estimate as 1.4x wind speed
        final gustValue = (details['wind_speed_of_gust'] as num?)?.toDouble();
        if (gustValue == null) {
          windGusts.add(speed * 1.4); // Typical gust factor
        } else {
          windGusts.add(gustValue);
        }
        
        humidity.add((details['relative_humidity'] as num?)?.toInt() ?? 0);
        pressure.add((details['air_pressure_at_sea_level'] as num?)?.toDouble() ?? 1013.0);
        cloudCover.add((details['cloud_area_fraction'] as num?)?.toInt() ?? 0);
        
        // Calculate dewpoint from temperature and humidity (Magnus formula)
        // MET Norway doesn't provide dewpoint directly
        final rh = (details['relative_humidity'] as num?)?.toDouble() ?? 0.0;
        final dewpointCalc = _calculateDewpoint(temp, rh);
        dewpoint.add(dewpointCalc);
        
        // MET Norway doesn't provide UV index in instant details
        // It may be in forecast periods, but for now we'll set to 0
        uvIndex.add(0.0);
        
        // Visibility in meters to km
        final visMeters = (details['visibility'] as num?)?.toDouble() ?? 10000.0;
        visibility.add(visMeters / 1000.0);

        // Get precipitation from next_1_hours or next_6_hours
        double precipAmount = 0.0;
        final next1h = data['next_1_hours'];
        final next6h = data['next_6_hours'];
        
        if (next1h != null && next1h is Map<String, dynamic>) {
          final precipDetails = next1h['details'];
          if (precipDetails != null && precipDetails is Map<String, dynamic>) {
            precipAmount = (precipDetails['precipitation_amount'] as num?)?.toDouble() ?? 0.0;
          }
        } else if (next6h != null && next6h is Map<String, dynamic>) {
          final precipDetails = next6h['details'];
          if (precipDetails != null && precipDetails is Map<String, dynamic>) {
            precipAmount = (precipDetails['precipitation_amount'] as num?)?.toDouble() ?? 0.0;
          }
        }
        precipitation.add(precipAmount);

        // Get weather code from symbol
        int weatherCode = 0;
        if (next1h != null && next1h is Map<String, dynamic>) {
          final summary = next1h['summary'];
          if (summary != null && summary is Map<String, dynamic>) {
            final symbolCode = summary['symbol_code'] as String?;
            weatherCode = _convertSymbolToWeatherCode(symbolCode);
          }
        } else if (next6h != null && next6h is Map<String, dynamic>) {
          final summary = next6h['summary'];
          if (summary != null && summary is Map<String, dynamic>) {
            final symbolCode = summary['symbol_code'] as String?;
            weatherCode = _convertSymbolToWeatherCode(symbolCode);
          }
        }
        weatherCodes.add(weatherCode);
      }

      if (times.isEmpty) {
        debugPrint('❌ No valid entries in MET Norway timeseries');
        return null;
      }

      debugPrint('✅ Converted ${times.length} MET Norway entries');
      debugPrint('📊 Sample times: ${times.take(3).toList()}');
      debugPrint('📊 Sample temps: ${temps.take(3).toList()}');
      debugPrint('📊 Sample weather codes: ${weatherCodes.take(3).toList()}');

      // Fetch sunrise/sunset data if coordinates provided
      List<String> sunriseData = [];
      List<String> sunsetData = [];
      
      if (lat != null && lon != null && times.isNotEmpty) {
        try {
          final firstDate = DateTime.parse(times.first);
          
          // MET Norway Sunrise API doesn't support 'days' parameter, need to make multiple requests
          for (int i = 0; i < 11; i++) {
            final requestDate = firstDate.add(Duration(days: i));
            final sunData = await MetNoService.getSunrise(lat: lat, lon: lon, date: requestDate, days: 1);
            
            debugPrint('🔍 Day $i: sunData is ${sunData != null ? "not null" : "null"}');
            
            if (sunData != null && sunData['properties'] != null) {
              final props = sunData['properties'] as Map<String, dynamic>?;
              debugPrint('🔍 Day $i: props is ${props != null ? "not null" : "null"}');
              
              if (props != null) {
                // The sunrise/sunset might be objects with time property, not direct strings
                final sunrise = props['sunrise'];
                final sunset = props['sunset'];
                
                String? sunriseStr;
                String? sunsetStr;
                
                // Check if sunrise/sunset are strings or objects
                if (sunrise is String) {
                  sunriseStr = sunrise;
                } else if (sunrise is Map<String, dynamic>) {
                  sunriseStr = sunrise['time'] as String?;
                }
                
                if (sunset is String) {
                  sunsetStr = sunset;
                } else if (sunset is Map<String, dynamic>) {
                  sunsetStr = sunset['time'] as String?;
                }
                
                debugPrint('🔍 Day $i: sunrise=$sunriseStr, sunset=$sunsetStr');
                
                // Store the full ISO8601 timestamps (converted to local time)
                if (sunriseStr != null) {
                  try {
                    final sunriseTime = DateTime.parse(sunriseStr).toLocal();
                    sunriseData.add(sunriseTime.toIso8601String());
                  } catch (e) {
                    debugPrint('⚠️ Error parsing sunrise time: $e');
                  }
                }
                
                if (sunsetStr != null) {
                  try {
                    final sunsetTime = DateTime.parse(sunsetStr).toLocal();
                    sunsetData.add(sunsetTime.toIso8601String());
                  } catch (e) {
                    debugPrint('⚠️ Error parsing sunset time: $e');
                  }
                }
              }
            }
            
            // Small delay to avoid rate limiting
            if (i < 10) {
              await Future.delayed(Duration(milliseconds: 100));
            }
          }
          
          if (sunriseData.isNotEmpty && sunsetData.isNotEmpty) {
            debugPrint('🌅 Fetched ${sunriseData.length} sunrise and ${sunsetData.length} sunset times from MET Norway');
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch sunrise/sunset data: $e');
        }
      }
      
      // Extract daily dates to know how many days we need
      final dailyDates = _extractDailyTimes(times);
      final expectedDays = dailyDates.length;
      
      // If we didn't get enough data, fill in with approximations
      if (sunriseData.length < expectedDays || sunsetData.length < expectedDays) {
        debugPrint('⚠️ Got ${sunriseData.length} sunrise and ${sunsetData.length} sunset, but need $expectedDays. Filling with approximations.');
        final approxSunrise = _generateDailySunriseSunset(times, true);
        final approxSunset = _generateDailySunriseSunset(times, false);
        
        // Use real data where available, approximations for the rest
        while (sunriseData.length < expectedDays && sunriseData.length < approxSunrise.length) {
          sunriseData.add(approxSunrise[sunriseData.length]);
        }
        while (sunsetData.length < expectedDays && sunsetData.length < approxSunset.length) {
          sunsetData.add(approxSunset[sunsetData.length]);
        }
      }
      
      // Final check - if still empty, use all approximations
      if (sunriseData.isEmpty || sunsetData.isEmpty) {
        debugPrint('⚠️ Using approximated sunrise/sunset times');
        sunriseData = _generateDailySunriseSunset(times, true);
        sunsetData = _generateDailySunriseSunset(times, false);
      }
      
      debugPrint('📅 Final sunrise data (first 3): ${sunriseData.take(3).toList()}');
      debugPrint('📅 Final sunset data (first 3): ${sunsetData.take(3).toList()}');
      debugPrint('⚠️ If you see HH:mm format errors, please CLEAR CACHE in app settings!');

      return {
        'hourly': {
          'time': times,
          'temperature_2m': temps,
          'precipitation': precipitation,
          'weathercode': weatherCodes,
          'windspeed_10m': windSpeed,
          'winddirection_10m': windDirection,
          'windgusts_10m': windGusts,
          'relativehumidity_2m': humidity,
          'surface_pressure': pressure,
          'cloudcover': cloudCover,
          'visibility': visibility,
          'dewpoint_2m': dewpoint,
          'uv_index': uvIndex,
        },
        'hourly_units': {
          'time': 'iso8601',
          'temperature_2m': '°C',
          'precipitation': 'mm',
          'weather_code': 'wmo code',
          'wind_speed_10m': 'm/s',
          'wind_direction_10m': '°',
          'relative_humidity_2m': '%',
          'surface_pressure': 'hPa',
          'cloud_cover': '%',
          'visibility': 'km',
        },
        'daily': {
          'time': _extractDailyTimes(times),
          'temperature_2m_max': _extractDailyMax(times, temps),
          'temperature_2m_min': _extractDailyMin(times, temps),
          'precipitation_sum': _extractDailySum(times, precipitation),
          'weathercode': _extractDailyWeatherCodes(times, weatherCodes),
          'windspeed_10m_max': _extractDailyMax(times, windSpeed),
          'windgusts_10m_max': _extractDailyMax(times, windGusts),
          'uv_index_max': _extractDailyMax(times, uvIndex),
          'winddirection_10m_dominant': _extractDailyDominant(times, windDirection),
          'sunrise': sunriseData,
          'sunset': sunsetData,
        },
        'timezone': 'auto',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error converting MET Norway to Open-Meteo format: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Extract daily time entries from hourly data
  static List<String> _extractDailyTimes(List<String> hourlyTimes) {
    final dailyDates = <String>{};
    for (var time in hourlyTimes) {
      try {
        final date = DateTime.parse(time);
        dailyDates.add('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
      } catch (e) {
        // Skip invalid dates
      }
    }
    final result = dailyDates.toList();
    debugPrint('📅 Extracted ${result.length} daily dates from ${hourlyTimes.length} hourly times');
    return result;
  }

  /// Extract daily max values from hourly data
  static List<double> _extractDailyMax(List<String> times, List<double> values) {
    debugPrint('🔍 _extractDailyMax called with ${times.length} times and ${values.length} values');
    final dailyMax = <String, double>{};
    for (var i = 0; i < times.length && i < values.length; i++) {
      try {
        final date = DateTime.parse(times[i]);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (!dailyMax.containsKey(dateKey) || values[i] > dailyMax[dateKey]!) {
          dailyMax[dateKey] = values[i];
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing time in _extractDailyMax: $e at index $i: ${times[i]}');
      }
    }
    final result = dailyMax.values.toList();
    debugPrint('📈 _extractDailyMax result: ${result.length} days, values: $result');
    return result;
  }

  /// Extract daily min values from hourly data
  static List<double> _extractDailyMin(List<String> times, List<double> values) {
    final dailyMin = <String, double>{};
    for (var i = 0; i < times.length && i < values.length; i++) {
      try {
        final date = DateTime.parse(times[i]);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (!dailyMin.containsKey(dateKey) || values[i] < dailyMin[dateKey]!) {
          dailyMin[dateKey] = values[i];
        }
      } catch (e) {
        // Skip invalid entries
      }
    }
    return dailyMin.values.toList();
  }

  /// Extract daily sum values from hourly data
  static List<double> _extractDailySum(List<String> times, List<double> values) {
    final dailySum = <String, double>{};
    for (var i = 0; i < times.length && i < values.length; i++) {
      try {
        final date = DateTime.parse(times[i]);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailySum[dateKey] = (dailySum[dateKey] ?? 0.0) + values[i];
      } catch (e) {
        // Skip invalid entries
      }
    }
    return dailySum.values.toList();
  }

  /// Extract most common weather code per day
  static List<int> _extractDailyWeatherCodes(List<String> times, List<int> codes) {
    final dailyCodes = <String, Map<int, int>>{};
    for (var i = 0; i < times.length && i < codes.length; i++) {
      try {
        final date = DateTime.parse(times[i]);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyCodes.putIfAbsent(dateKey, () => {});
        dailyCodes[dateKey]![codes[i]] = (dailyCodes[dateKey]![codes[i]] ?? 0) + 1;
      } catch (e) {
        debugPrint('⚠️ Error parsing time for weather code: $e');
      }
    }
    
    // Get most frequent code per day
    final result = dailyCodes.values.map((codeMap) {
      var maxCount = 0;
      var mostFrequentCode = 0;
      codeMap.forEach((code, count) {
        if (count > maxCount) {
          maxCount = count;
          mostFrequentCode = code;
        }
      });
      return mostFrequentCode;
    }).toList();
    
    debugPrint('🌤️ Extracted ${result.length} daily weather codes from ${times.length} hourly entries');
    return result;
  }
  
  /// Extract dominant (most frequent) wind direction per day
  static List<int> _extractDailyDominant(List<String> times, List<double> values) {
    if (times.isEmpty || values.isEmpty) return [];
    
    final dailyDirections = <String, Map<int, int>>{};
    
    for (int i = 0; i < times.length && i < values.length; i++) {
      try {
        final date = DateTime.parse(times[i]);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final direction = values[i].round();
        
        dailyDirections.putIfAbsent(dateKey, () => {});
        dailyDirections[dateKey]![direction] = (dailyDirections[dateKey]![direction] ?? 0) + 1;
      } catch (e) {
        debugPrint('⚠️ Error parsing time for wind direction: $e');
      }
    }
    
    // Get most frequent direction per day
    final result = dailyDirections.values.map((dirMap) {
      var maxCount = 0;
      var dominantDir = 0;
      dirMap.forEach((dir, count) {
        if (count > maxCount) {
          maxCount = count;
          dominantDir = dir;
        }
      });
      return dominantDir;
    }).toList();
    
    return result;
  }

  /// Generate sunrise/sunset times (placeholder using reasonable estimates)
  /// MET Norway has a separate Sunrise API, but for now we'll use approximations
  static List<String> _generateDailySunriseSunset(List<String> times, bool isSunrise) {
    final dailyTimes = <String>[];
    final seenDates = <String>{};
    
    for (var time in times) {
      try {
        final date = DateTime.parse(time);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        if (!seenDates.contains(dateKey)) {
          seenDates.add(dateKey);
          // Approximate sunrise at 7 AM, sunset at 7 PM local time
          final hour = isSunrise ? 7 : 19;
          final approximateTime = DateTime(date.year, date.month, date.day, hour, 0);
          dailyTimes.add(approximateTime.toIso8601String());
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    
    return dailyTimes;
  }
}
