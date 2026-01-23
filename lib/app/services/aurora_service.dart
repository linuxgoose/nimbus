import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';
import 'package:flutter/foundation.dart';

class AuroraService {
  static const cacheDuration = Duration(minutes: 60);
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Generate location key from coordinates
  static String _getLocationKey(double lat, double lon) {
    return '${lat.toStringAsFixed(2)}_${lon.toStringAsFixed(2)}';
  }

  // Check if cached data is still valid
  static bool isCacheValid(double lat, double lon) {
    try {
      final locationKey = _getLocationKey(lat, lon);
      final cache = isar.auroraCaches.getByLocationKeySync(locationKey);

      if (cache?.cachedAt == null) {
        debugPrint('🌌 Aurora Cache: No cache found for $locationKey');
        return false;
      }

      final age = DateTime.now().difference(cache!.cachedAt!);
      final isValid = age < cacheDuration;
      debugPrint(
        '🌌 Aurora Cache: Found cache for $locationKey, age: ${age.inMinutes}min, valid: $isValid',
      );
      return isValid;
    } catch (e) {
      debugPrint('🌌 Aurora Cache: Error checking cache: $e');
      return false;
    }
  }

  // Get cached aurora data
  static Map<String, dynamic>? getCachedData(double lat, double lon) {
    try {
      final locationKey = _getLocationKey(lat, lon);
      final cache = isar.auroraCaches.getByLocationKeySync(locationKey);

      if (cache == null) return null;

      return {
        'kp_index': cache.kpIndex,
        'timestamp': cache.timestamp,
        'activity_level': cache.activityLevel,
        'uk_status': cache.ukStatus,
        'forecast': cache.forecastJson != null
            ? json.decode(cache.forecastJson!)
            : null,
        'cached_at': cache.cachedAt?.toIso8601String(),
        'source': 'Cache',
      };
    } catch (e) {
      return null;
    }
  }

  // Store aurora data in cache
  static void cacheData({
    required double lat,
    required double lon,
    required double? kpIndex,
    required String? timestamp,
    required String? activityLevel,
    String? ukStatus,
    List<dynamic>? forecast,
  }) {
    try {
      final locationKey = _getLocationKey(lat, lon);
      debugPrint(
        '🌌 Aurora Cache: Storing data for $locationKey, Kp: $kpIndex',
      );

      isar.writeTxnSync(() {
        final newCache = AuroraCache()
          ..locationKey = locationKey
          ..latitude = lat
          ..longitude = lon
          ..kpIndex = kpIndex
          ..timestamp = timestamp
          ..activityLevel = activityLevel
          ..ukStatus = ukStatus
          ..forecastJson = forecast != null ? json.encode(forecast) : null
          ..cachedAt = DateTime.now();

        isar.auroraCaches.putByLocationKeySync(newCache);
      });
      debugPrint('🌌 Aurora Cache: Successfully stored cache');
    } catch (e) {
      debugPrint('🌌 Aurora Cache: Error storing cache: $e');
      // Silently fail - caching is not critical
    }
  }

  // Get aurora data with cache support
  static Future<Map<String, dynamic>?> getAuroraData({
    required double lat,
    required double lon,
    bool forceRefresh = false,
  }) async {
    debugPrint(
      '🌌 Aurora: Getting data for $lat, $lon (forceRefresh: $forceRefresh)',
    );

    // Check cache first unless force refresh
    if (!forceRefresh && isCacheValid(lat, lon)) {
      debugPrint('🌌 Aurora: Using cached data');
      final cachedData = getCachedData(lat, lon);
      if (cachedData != null) return cachedData;
    }

    debugPrint('🌌 Aurora: Fetching fresh data from APIs');
    // Fetch fresh data
    final noaaData = await getNoaaAuroraData();
    if (noaaData == null) return null;

    final ukData = await getAuroraWatchUK();
    final forecast = await getThreeDayForecast();
    final activityLevel = getActivityLevel(noaaData['kp_index'] as double);

    debugPrint('🌌 Aurora: Caching fresh data');
    // Cache the fresh data
    cacheData(
      lat: lat,
      lon: lon,
      kpIndex: noaaData['kp_index'] as double?,
      timestamp: noaaData['timestamp'] as String?,
      activityLevel: activityLevel,
      ukStatus: ukData?['status'] as String?,
      forecast: forecast,
    );

    return {
      ...noaaData,
      'activity_level': activityLevel,
      'uk_status': ukData?['status'],
      'forecast': forecast,
      'source': 'Live',
    };
  }

  // NOAA SWPC - Global aurora data
  static Future<Map<String, dynamic>?> getNoaaAuroraData() async {
    try {
      // Get current Kp index
      final kpResponse = await _dio.get(
        'https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json',
      );

      if (kpResponse.statusCode == 200) {
        final kpData = kpResponse.data as List;
        if (kpData.length > 1) {
          // Latest reading is last entry (skip header row)
          final latest = kpData.last;
          return {
            'kp_index': double.tryParse(latest[1].toString()) ?? 0.0,
            'timestamp': latest[0],
            'source': 'NOAA SWPC',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // AuroraWatch UK - UK-specific alerts
  static Future<Map<String, dynamic>?> getAuroraWatchUK() async {
    try {
      final response = await _dio.get(
        'https://aurorawatch.lancs.ac.uk/api/0.2/status.json',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'status_id': data['status_id'],
          'status': data['status'],
          'updated': data['updated'],
          'source': 'AuroraWatch UK',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get 3-day aurora forecast from NOAA
  static Future<List<Map<String, dynamic>>?> getThreeDayForecast() async {
    try {
      final response = await _dio.get(
        'https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json',
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final forecast = <Map<String, dynamic>>[];
        final now = DateTime.now().toUtc();

        // Skip header row
        for (var i = 1; i < data.length; i++) {
          final entry = data[i];
          final timestamp = entry[0] as String;
          final dataType =
              entry[2] as String?; // observed, estimated, or predicted

          // Parse the timestamp
          try {
            final entryTime = DateTime.parse(timestamp);

            // Only include current and future data (estimated or predicted)
            // Skip past "observed" data
            if (dataType != 'observed' &&
                !entryTime.isBefore(now.subtract(const Duration(hours: 3)))) {
              forecast.add({
                'timestamp': timestamp,
                'kp_predicted': double.tryParse(entry[1].toString()) ?? 0.0,
                'data_type': dataType,
              });
            }
          } catch (e) {
            // Skip entries with invalid timestamps
            continue;
          }
        }
        return forecast;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Calculate visibility based on Kp index and latitude
  static String getVisibilityForLocation(double kp, double latitude) {
    final absLat = latitude.abs();

    if (kp >= 9) {
      return absLat >= 30 ? 'Very High' : 'High';
    } else if (kp >= 7) {
      return absLat >= 40
          ? 'High'
          : absLat >= 30
          ? 'Moderate'
          : 'Low';
    } else if (kp >= 5) {
      return absLat >= 50
          ? 'High'
          : absLat >= 45
          ? 'Moderate'
          : 'Low';
    } else if (kp >= 4) {
      return absLat >= 55
          ? 'Moderate'
          : absLat >= 50
          ? 'Low'
          : 'Very Low';
    } else if (kp >= 3) {
      return absLat >= 60
          ? 'Moderate'
          : absLat >= 55
          ? 'Low'
          : 'Very Low';
    } else {
      return absLat >= 65 ? 'Low' : 'Very Low';
    }
  }

  // Get activity level description
  static String getActivityLevel(double kp) {
    if (kp >= 9) return 'Extreme Storm';
    if (kp >= 8) return 'Severe Storm';
    if (kp >= 7) return 'Strong Storm';
    if (kp >= 6) return 'Moderate Storm';
    if (kp >= 5) return 'Minor Storm';
    if (kp >= 4) return 'Active';
    if (kp >= 3) return 'Unsettled';
    return 'Quiet';
  }

  // Get color for Kp index
  static String getKpColor(double kp) {
    if (kp >= 8) return '#FF0000'; // Red - Extreme
    if (kp >= 6) return '#FF6600'; // Orange - Strong
    if (kp >= 5) return '#FFAA00'; // Yellow - Moderate
    if (kp >= 4) return '#FFFF00'; // Light Yellow - Active
    if (kp >= 3) return '#00FF00'; // Green - Unsettled
    return '#00AA00'; // Dark Green - Quiet
  }

  // Get AuroraWatch UK alert color
  static String getUKAlertColor(String status) {
    switch (status.toLowerCase()) {
      case 'red':
        return '#FF0000';
      case 'amber':
        return '#FFAA00';
      case 'yellow':
        return '#FFFF00';
      case 'green':
      default:
        return '#00AA00';
    }
  }

  // Get Solar Wind Speed from NOAA SWPC
  static Future<Map<String, dynamic>?> getSolarWindSpeed() async {
    try {
      final response = await _dio.get(
        'https://services.swpc.noaa.gov/products/solar-wind/mag-2-hour.json',
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        if (data.length > 1) {
          // Latest reading is last entry (skip header row)
          final latest = data.last;
          final speed = double.tryParse(latest[6].toString()) ?? 0.0;

          return {
            'speed': speed,
            'timestamp': latest[0],
            'status': _getSolarWindStatus(speed),
            'color': _getSolarWindColor(speed),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _getSolarWindStatus(double speed) {
    if (speed >= 700) return 'Storm';
    if (speed >= 500) return 'Elevated';
    if (speed >= 300) return 'Normal';
    return 'Low';
  }

  static String _getSolarWindColor(double speed) {
    if (speed >= 700) return '#FF0000'; // Red - Storm
    if (speed >= 500) return '#FFAA00'; // Orange - Elevated
    if (speed >= 300) return '#00AA00'; // Green - Normal
    return '#666666'; // Gray - Low
  }

  // Get recent Solar Flares from NASA DONKI
  static Future<List<Map<String, dynamic>>?> getSolarFlares({
    int daysBack = 7,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: daysBack));
      final dateStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

      final response = await _dio.get(
        'https://api.nasa.gov/DONKI/FLR?startDate=$dateStr&api_key=DEMO_KEY',
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final flares = <Map<String, dynamic>>[];

        for (var flare in data) {
          flares.add({
            'beginTime': flare['beginTime'],
            'peakTime': flare['peakTime'],
            'endTime': flare['endTime'],
            'classType': flare['classType'],
            'sourceLocation': flare['sourceLocation'],
            'activeRegionNum': flare['activeRegionNum'],
            'severity': _getFlareClassType(flare['classType']),
            'color': _getFlareColor(flare['classType']),
          });
        }

        return flares;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _getFlareClassType(String? classType) {
    if (classType == null) return 'Unknown';
    final firstChar = classType[0].toUpperCase();
    if (firstChar == 'X') return 'Extreme';
    if (firstChar == 'M') return 'Strong';
    if (firstChar == 'C') return 'Moderate';
    if (firstChar == 'B') return 'Minor';
    return 'Weak';
  }

  static String _getFlareColor(String? classType) {
    if (classType == null) return '#666666';
    final firstChar = classType[0].toUpperCase();
    if (firstChar == 'X') return '#FF0000'; // Red - Extreme
    if (firstChar == 'M') return '#FF6600'; // Orange - Strong
    if (firstChar == 'C') return '#FFAA00'; // Yellow - Moderate
    return '#00AA00'; // Green - Minor/Weak
  }

  // Get NASA Astronomy Picture of the Day
  static Future<Map<String, dynamic>?> getNasaAPOD() async {
    try {
      final response = await _dio.get(
        'https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'title': data['title'],
          'explanation': data['explanation'],
          'url': data['url'],
          'hdurl': data['hdurl'],
          'date': data['date'],
          'mediaType': data['media_type'],
          'copyright': data['copyright'],
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get recent earthquakes from USGS (magnitude 2.5+ in past 7 days)
  static Future<List<Map<String, dynamic>>?> getRecentEarthquakes({
    double? latitude,
    double? longitude,
    double radiusKm = 1000,
    double minMagnitude = 2.5,
  }) async {
    try {
      String url;
      if (latitude != null && longitude != null) {
        // Get earthquakes within radius of location
        url =
            'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson'
            '&latitude=$latitude&longitude=$longitude&maxradiuskm=$radiusKm'
            '&minmagnitude=$minMagnitude&orderby=time&limit=20';
      } else {
        // Get global significant earthquakes (4.5+ magnitude)
        url =
            'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson';
      }

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        final features = data['features'] as List;
        final earthquakes = <Map<String, dynamic>>[];

        for (var feature in features) {
          final props = feature['properties'];
          final geometry = feature['geometry'];
          final coords = geometry['coordinates'] as List;

          earthquakes.add({
            'magnitude': props['mag'],
            'place': props['place'],
            'time': props['time'],
            'updated': props['updated'],
            'tsunami': props['tsunami'] == 1,
            'felt': props['felt'],
            'cdi': props['cdi'], // Community Internet Intensity
            'alert': props['alert'], // green, yellow, orange, red
            'latitude': coords[1],
            'longitude': coords[0],
            'depth': coords[2],
            'url': props['url'],
            'color': _getEarthquakeColor(props['mag']),
            'severity': _getEarthquakeSeverity(props['mag']),
          });
        }

        return earthquakes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _getEarthquakeSeverity(double? magnitude) {
    if (magnitude == null) return 'Unknown';
    if (magnitude >= 8.0) return 'Great';
    if (magnitude >= 7.0) return 'Major';
    if (magnitude >= 6.0) return 'Strong';
    if (magnitude >= 5.0) return 'Moderate';
    if (magnitude >= 4.0) return 'Light';
    if (magnitude >= 3.0) return 'Minor';
    return 'Micro';
  }

  static String _getEarthquakeColor(double? magnitude) {
    if (magnitude == null) return '#666666';
    if (magnitude >= 7.0) return '#FF0000'; // Red - Major/Great
    if (magnitude >= 6.0) return '#FF6600'; // Orange - Strong
    if (magnitude >= 5.0) return '#FFAA00'; // Yellow - Moderate
    if (magnitude >= 4.0) return '#FFDD00'; // Light Yellow - Light
    return '#00AA00'; // Green - Minor
  }

  // Get weather alerts from National Weather Service (US only)
  static Future<List<Map<String, dynamic>>?> getNWSAlerts({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // NWS requires a User-Agent header
      final response = await _dio.get(
        'https://api.weather.gov/alerts/active?point=$latitude,$longitude',
        options: Options(
          headers: {
            'User-Agent': '(Nimbus Weather App, contact@nimbusmeteo.com)',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final features = data['features'] as List?;

        if (features == null || features.isEmpty) return [];

        final alerts = <Map<String, dynamic>>[];

        for (var feature in features) {
          final props = feature['properties'];

          alerts.add({
            'event': props['event'],
            'headline': props['headline'],
            'description': props['description'],
            'instruction': props['instruction'],
            'severity': props['severity'], // Extreme, Severe, Moderate, Minor
            'certainty': props['certainty'], // Observed, Likely, Possible
            'urgency': props['urgency'], // Immediate, Expected, Future
            'onset': props['onset'],
            'expires': props['expires'],
            'senderName': props['senderName'],
            'areaDesc': props['areaDesc'],
            'color': _getNWSSeverityColor(props['severity']),
          });
        }

        return alerts;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static String _getNWSSeverityColor(String? severity) {
    if (severity == null) return '#666666';
    switch (severity.toLowerCase()) {
      case 'extreme':
        return '#FF0000'; // Red
      case 'severe':
        return '#FF6600'; // Orange
      case 'moderate':
        return '#FFAA00'; // Yellow
      case 'minor':
        return '#FFDD00'; // Light Yellow
      default:
        return '#00AA00'; // Green
    }
  }

  // Get additional NOAA SWPC data - Geomagnetic Storm Watches/Warnings
  static Future<List<Map<String, dynamic>>?> getGeomagneticStormData() async {
    try {
      final response = await _dio.get(
        'https://services.swpc.noaa.gov/products/alerts.json',
      );

      if (response.statusCode == 200) {
        final data = response.data as List;
        final storms = <Map<String, dynamic>>[];

        for (var alert in data) {
          final message = alert['message'] as String?;
          if (message != null &&
              (message.contains('Geomagnetic Storm') ||
                  message.contains('Watch') ||
                  message.contains('Warning'))) {
            storms.add({
              'message': message,
              'issueTime': alert['issue_datetime'],
              'product': alert['product_id'],
            });
          }
        }

        return storms;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
