import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for UK Flood Monitoring APIs
/// England: https://environment.data.gov.uk/flood-monitoring/doc/reference
/// Scotland (SEPA): https://www2.sepa.org.uk/fwa/
/// Wales (NRW): https://api.naturalresources.wales/
class FloodService {
  static const String _baseUrl =
      'https://environment.data.gov.uk/flood-monitoring';
  static const String _sepaUrl = 'https://www2.sepa.org.uk/fwa';
  static const String _nrwUrl =
      'https://api.naturalresources.wales/rivers-and-seas/v1';
  static const String _userAgent =
      'Nimbus Weather App github.com/linuxgoose/nimbus';

  /// Get all active flood warnings and alerts
  /// Returns list of current flood warnings for England
  static Future<Map<String, dynamic>?> getFloodWarnings() async {
    try {
      final url = Uri.parse('$_baseUrl/id/floods');

      debugPrint('🌊 Calling Flood Warnings API: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Flood Warnings API Success');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ Flood Warnings API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Flood Warnings API Exception: $e');
      return null;
    }
  }

  /// Get flood warnings for a specific area
  /// lat/lon parameters to filter by proximity
  static Future<List<Map<String, dynamic>>> getFloodWarningsNearLocation({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
  }) async {
    try {
      final allWarnings = await getFloodWarnings();
      if (allWarnings == null) return [];

      final items = allWarnings['items'] as List<dynamic>?;
      if (items == null) return [];

      final nearbyWarnings = <Map<String, dynamic>>[];

      for (var item in items) {
        final floodArea = item['floodArea'] as Map<String, dynamic>?;
        if (floodArea == null) continue;

        final polygon = floodArea['polygon'] as String?;
        if (polygon == null) continue;

        // Parse polygon and check if location is nearby
        if (_isLocationNearFloodArea(lat, lon, polygon, radiusKm)) {
          nearbyWarnings.add({
            'severity': item['severity'] as String? ?? 'Unknown',
            'severityLevel': item['severityLevel'] as int? ?? 0,
            'description': item['description'] as String? ?? '',
            'message': item['message'] as String? ?? '',
            'floodAreaID': floodArea['floodAreaId'] as String? ?? '',
            'county': floodArea['county'] as String? ?? '',
            'notation': floodArea['notation'] as String? ?? '',
            'polygon': polygon,
            'timeRaised': item['timeRaised'] as String?,
            'timeMessageChanged': item['timeMessageChanged'] as String?,
            'timeSeverityChanged': item['timeSeverityChanged'] as String?,
          });
        }
      }

      debugPrint('✅ Found ${nearbyWarnings.length} nearby flood warnings');
      return nearbyWarnings;
    } catch (e) {
      debugPrint('❌ Flood Warnings Near Location Exception: $e');
      return [];
    }
  }

  /// Get all flood monitoring stations
  /// Optional lat/lon to get stations near location
  /// Note: The API doesn't support location filtering, so we fetch all and filter client-side
  static Future<Map<String, dynamic>?> getStations({
    double? lat,
    double? lon,
    int? limit,
  }) async {
    try {
      // The Environment Agency API doesn't support lat/long parameters
      // We fetch all stations and filter by distance in getAllUKStations
      final url = '$_baseUrl/id/stations';

      debugPrint('📊 Calling Stations API: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;
        debugPrint(
          '✅ Stations API Success - Found ${items?.length ?? 0} total stations',
        );
        return data;
      } else {
        debugPrint('❌ Stations API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Stations API Exception: $e');
      return null;
    }
  }

  /// Get river level readings for a specific station
  static Future<Map<String, dynamic>?> getStationReadings(
    String stationId,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/id/stations/$stationId/readings');

      debugPrint('📈 Calling Station Readings API: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Station Readings API Success');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ Station Readings API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Station Readings API Exception: $e');
      return null;
    }
  }

  /// Get flood areas (regions that can flood)
  static Future<Map<String, dynamic>?> getFloodAreas() async {
    try {
      final url = Uri.parse('$_baseUrl/id/floodAreas');

      debugPrint('🗺️ Calling Flood Areas API: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Flood Areas API Success');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ Flood Areas API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Flood Areas API Exception: $e');
      return null;
    }
  }

  /// Get all UK monitoring stations (England only)
  /// Note: Scotland and Wales do not provide public APIs for monitoring stations
  static Future<List<Map<String, dynamic>>> getAllUKStations({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
    int? limit,
  }) async {
    try {
      final allStations = <Map<String, dynamic>>[];

      // England stations (Environment Agency)
      final englandData = await getStations(lat: lat, lon: lon, limit: limit);

      if (englandData != null) {
        final items = englandData['items'] as List<dynamic>?;
        debugPrint('🔍 England data items: ${items?.length ?? 0}');
        if (items != null) {
          debugPrint('🔍 Starting distance filtering...');
          for (var item in items) {
            try {
              final sLat = item['lat'] as double?;
              final sLon = item['long'] as double?;
              if (sLat != null && sLon != null) {
                // Calculate distance from user location
                final distance = _calculateDistance(lat, lon, sLat, sLon);
                if (distance <= radiusKm) {
                  allStations.add({
                    'stationReference':
                        item['stationReference'] as String? ?? '',
                    'label': item['label'] as String? ?? 'Unknown Station',
                    'lat': sLat,
                    'long': sLon,
                    'notation': item['notation'] as String? ?? '',
                    'riverName': item['riverName'] as String?,
                    'region': 'England',
                    'distance': distance,
                  });
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error processing station: $e');
              continue;
            }
          }
          debugPrint(
            '🔍 Filtering complete, found ${allStations.length} nearby stations',
          );
        }
      }

      // Sort by distance and apply limit
      allStations.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
      final stations = limit != null && allStations.length > limit
          ? allStations.sublist(0, limit)
          : allStations;

      debugPrint(
        '✅ Total UK monitoring stations within ${radiusKm}km: ${stations.length}',
      );
      return stations;
    } catch (e) {
      debugPrint('❌ Error in getAllUKStations: $e');
      return [];
    }
  }

  /// Check if location is near a flood area polygon
  static bool _isLocationNearFloodArea(
    double lat,
    double lon,
    String polygonString,
    double radiusKm,
  ) {
    try {
      // Parse polygon string format: "lat1 lon1, lat2 lon2, ..."
      final points = polygonString.split(',');

      for (var point in points) {
        final coords = point.trim().split(' ');
        if (coords.length >= 2) {
          final pLat = double.tryParse(coords[0]);
          final pLon = double.tryParse(coords[1]);

          if (pLat != null && pLon != null) {
            final distance = _calculateDistance(lat, lon, pLat, pLon);
            if (distance <= radiusKm) {
              return true;
            }
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Error parsing polygon: $e');
      return false;
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Get severity color for flood warnings
  static String getSeverityColor(int severityLevel) {
    switch (severityLevel) {
      case 1: // Severe Flood Warning
        return '#D50000'; // Dark red
      case 2: // Flood Warning
        return '#FF6D00'; // Orange
      case 3: // Flood Alert
        return '#FBC02D'; // Yellow
      case 4: // Warning No Longer In Force
        return '#43A047'; // Green
      default:
        return '#757575'; // Grey
    }
  }

  /// Get severity name
  static String getSeverityName(int severityLevel) {
    switch (severityLevel) {
      case 1:
        return 'Severe Flood Warning';
      case 2:
        return 'Flood Warning';
      case 3:
        return 'Flood Alert';
      case 4:
        return 'Warning No Longer In Force';
      default:
        return 'Unknown';
    }
  }

  /// Get SEPA flood warnings for Scotland
  /// Returns list of current flood warnings from SEPA
  static Future<List<Map<String, dynamic>>> getScotlandFloodWarnings({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
  }) async {
    try {
      // SEPA provides an RSS feed that we can parse
      final url = Uri.parse('$_sepaUrl/feeds/flood_warnings.xml');

      debugPrint('🏴󠁧󠁢󠁳󠁣󠁴󠁿 Calling SEPA Flood Warnings: $url');

      final response = await http.get(url, headers: {'User-Agent': _userAgent});

      if (response.statusCode == 200) {
        debugPrint('✅ SEPA Flood Warnings Success');
        // Parse RSS/XML and filter by location
        return _parseSEPAWarnings(response.body, lat, lon, radiusKm);
      } else {
        debugPrint('❌ SEPA API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ SEPA API Exception: $e');
      return [];
    }
  }

  /// Get NRW flood warnings for Wales
  /// Returns list of current flood warnings from Natural Resources Wales
  static Future<List<Map<String, dynamic>>> getWalesFloodWarnings({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
  }) async {
    try {
      // NRW API endpoint for flood warnings
      final url = Uri.parse('$_nrwUrl/flood-warnings');

      debugPrint('🏴󠁧󠁢󠁷󠁬󠁳󠁿 Calling NRW Flood Warnings: $url');

      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ NRW Flood Warnings Success');
        final data = jsonDecode(response.body);
        return _parseNRWWarnings(data, lat, lon, radiusKm);
      } else {
        debugPrint('❌ NRW API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ NRW API Exception: $e');
      return [];
    }
  }

  /// Get all UK flood warnings (England, Scotland, Wales)
  /// Automatically fetches from appropriate regional services
  static Future<List<Map<String, dynamic>>> getAllUKFloodWarnings({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
  }) async {
    final region = _determineUKRegion(lat, lon);
    debugPrint('📍 Detected region: $region');

    final warnings = <Map<String, dynamic>>[];

    // Always check England (Environment Agency)
    final englandWarnings = await getFloodWarningsNearLocation(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );
    warnings.addAll(englandWarnings.map((w) => {...w, 'region': 'England'}));

    // Check Scotland if in or near Scotland
    if (region == 'Scotland' || lat > 54.5) {
      final scotlandWarnings = await getScotlandFloodWarnings(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
      warnings.addAll(scotlandWarnings);
    }

    // Check Wales if in or near Wales
    if (region == 'Wales' ||
        (lat > 51.0 && lat < 53.5 && lon > -5.5 && lon < -2.5)) {
      final walesWarnings = await getWalesFloodWarnings(
        lat: lat,
        lon: lon,
        radiusKm: radiusKm,
      );
      warnings.addAll(walesWarnings);
    }

    debugPrint('✅ Total UK warnings found: ${warnings.length}');
    return warnings;
  }

  /// Determine UK region from coordinates
  static String _determineUKRegion(double lat, double lon) {
    // Scotland: roughly above 55°N
    if (lat >= 55.0) {
      return 'Scotland';
    }
    // Wales: roughly 51°N-53.5°N, 5.5°W-2.5°W
    if (lat >= 51.0 && lat <= 53.5 && lon >= -5.5 && lon <= -2.5) {
      return 'Wales';
    }
    // Northern Ireland: roughly 54°N-55.5°N, 8.5°W-5.5°W
    if (lat >= 54.0 && lat <= 55.5 && lon >= -8.5 && lon <= -5.5) {
      return 'Northern Ireland';
    }
    // Default to England
    return 'England';
  }

  /// Parse SEPA RSS/XML warnings
  static List<Map<String, dynamic>> _parseSEPAWarnings(
    String xmlBody,
    double lat,
    double lon,
    double radiusKm,
  ) {
    final warnings = <Map<String, dynamic>>[];

    try {
      // Basic XML parsing for RSS feed
      // Look for <item> elements in the feed
      final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);
      final matches = itemRegex.allMatches(xmlBody);

      for (var match in matches) {
        final itemContent = match.group(1) ?? '';

        // Extract title
        final titleMatch = RegExp(
          r'<title>(.*?)</title>',
        ).firstMatch(itemContent);
        final title = titleMatch?.group(1) ?? '';

        // Extract description
        final descMatch = RegExp(
          r'<description>(.*?)</description>',
        ).firstMatch(itemContent);
        final description = descMatch?.group(1) ?? '';

        // Extract link
        final linkMatch = RegExp(r'<link>(.*?)</link>').firstMatch(itemContent);
        final link = linkMatch?.group(1) ?? '';

        // Determine severity from title
        int severityLevel = 3; // Default to alert
        if (title.toLowerCase().contains('severe')) {
          severityLevel = 1;
        } else if (title.toLowerCase().contains('warning')) {
          severityLevel = 2;
        }

        warnings.add({
          'severity': title.contains('Severe')
              ? 'Severe Flood Warning'
              : title.contains('Warning')
              ? 'Flood Warning'
              : 'Flood Alert',
          'severityLevel': severityLevel,
          'description': title,
          'message': _cleanHtml(description),
          'floodAreaID': '',
          'county': 'Scotland',
          'notation': '',
          'polygon': '',
          'timeRaised': null,
          'timeMessageChanged': null,
          'timeSeverityChanged': null,
          'region': 'Scotland',
          'link': link,
        });
      }

      debugPrint('✅ Parsed ${warnings.length} SEPA warnings');
    } catch (e) {
      debugPrint('❌ Error parsing SEPA XML: $e');
    }

    return warnings;
  }

  /// Parse NRW JSON warnings
  static List<Map<String, dynamic>> _parseNRWWarnings(
    dynamic data,
    double lat,
    double lon,
    double radiusKm,
  ) {
    final warnings = <Map<String, dynamic>>[];

    try {
      if (data is Map<String, dynamic>) {
        final items = data['items'] as List<dynamic>?;

        if (items != null) {
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              // Extract severity
              final severity = item['severity'] as String? ?? 'Flood Alert';
              int severityLevel = 3;
              if (severity.toLowerCase().contains('severe')) {
                severityLevel = 1;
              } else if (severity.toLowerCase().contains('warning')) {
                severityLevel = 2;
              }

              warnings.add({
                'severity': severity,
                'severityLevel': severityLevel,
                'description': item['description'] as String? ?? '',
                'message': item['message'] as String? ?? '',
                'floodAreaID': item['area_code'] as String? ?? '',
                'county': 'Wales',
                'notation': '',
                'polygon': '',
                'timeRaised': item['time_raised'] as String?,
                'timeMessageChanged': item['time_message_changed'] as String?,
                'timeSeverityChanged': item['time_severity_changed'] as String?,
                'region': 'Wales',
              });
            }
          }
        }
      }

      debugPrint('✅ Parsed ${warnings.length} NRW warnings');
    } catch (e) {
      debugPrint('❌ Error parsing NRW data: $e');
    }

    return warnings;
  }

  /// Clean HTML tags from text
  static String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
