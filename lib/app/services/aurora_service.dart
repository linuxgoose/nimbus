import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';

class AuroraService {
  static const cacheDuration = Duration(minutes: 60);

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
        print('🌌 Aurora Cache: No cache found for $locationKey');
        return false;
      }

      final age = DateTime.now().difference(cache!.cachedAt!);
      final isValid = age < cacheDuration;
      print(
        '🌌 Aurora Cache: Found cache for $locationKey, age: ${age.inMinutes}min, valid: $isValid',
      );
      return isValid;
    } catch (e) {
      print('🌌 Aurora Cache: Error checking cache: $e');
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
      print('🌌 Aurora Cache: Storing data for $locationKey, Kp: $kpIndex');

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
      print('🌌 Aurora Cache: Successfully stored cache');
    } catch (e) {
      print('🌌 Aurora Cache: Error storing cache: $e');
      // Silently fail - caching is not critical
    }
  }

  // Get aurora data with cache support
  static Future<Map<String, dynamic>?> getAuroraData({
    required double lat,
    required double lon,
    bool forceRefresh = false,
  }) async {
    print(
      '🌌 Aurora: Getting data for $lat, $lon (forceRefresh: $forceRefresh)',
    );

    // Check cache first unless force refresh
    if (!forceRefresh && isCacheValid(lat, lon)) {
      print('🌌 Aurora: Using cached data');
      final cachedData = getCachedData(lat, lon);
      if (cachedData != null) return cachedData;
    }

    print('🌌 Aurora: Fetching fresh data from APIs');
    // Fetch fresh data
    final noaaData = await getNoaaAuroraData();
    if (noaaData == null) return null;

    final ukData = await getAuroraWatchUK();
    final forecast = await getThreeDayForecast();
    final activityLevel = getActivityLevel(noaaData['kp_index'] as double);

    print('🌌 Aurora: Caching fresh data');
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
      final kpResponse = await http.get(
        Uri.parse(
          'https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json',
        ),
      );

      if (kpResponse.statusCode == 200) {
        final kpData = json.decode(kpResponse.body) as List;
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
      final response = await http.get(
        Uri.parse('https://aurorawatch.lancs.ac.uk/api/0.2/status.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
      final response = await http.get(
        Uri.parse(
          'https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final forecast = <Map<String, dynamic>>[];

        // Skip header row
        for (var i = 1; i < data.length; i++) {
          final entry = data[i];
          forecast.add({
            'timestamp': entry[0],
            'kp_predicted': double.tryParse(entry[1].toString()) ?? 0.0,
            'kp_observed': entry[2] != null
                ? double.tryParse(entry[2].toString())
                : null,
          });
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
}
