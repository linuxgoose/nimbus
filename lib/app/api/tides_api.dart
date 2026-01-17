import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';

class TidesAPI {
  /// Fetch all available UK Tidal API Discovery stations
  Future<List<Map<String, dynamic>>> getUkTidalDiscoveryStations(
    String? apiKey,
  ) async {
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[UK Tidal API] No API key provided for station list.');
      return [];
    }
    try {
      final url =
          'https://admiraltyapi.azure-api.net/uktidalapi/api/V1/Stations';
      debugPrint('[UK Tidal API] Fetching all stations: $url');
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Ocp-Apim-Subscription-Key': apiKey}),
      );
      debugPrint('[UK Tidal API] Stations response: ${resp.statusCode}');
      debugPrint('[UK Tidal API] Response data type: ${resp.data.runtimeType}');
      debugPrint('[UK Tidal API] Response data: ${resp.data}');

      if (resp.data is List) {
        final list = List<Map<String, dynamic>>.from(resp.data);
        debugPrint('[UK Tidal API] Found ${list.length} stations');
        return list;
      } else if (resp.data is Map) {
        // Check if it's wrapped in a features array or similar
        final map = resp.data as Map<String, dynamic>;
        debugPrint('[UK Tidal API] Response is a map with keys: ${map.keys}');

        // Try common API response patterns
        if (map.containsKey('features') && map['features'] is List) {
          final features = map['features'] as List;
          final stations = <Map<String, dynamic>>[];

          // Transform GeoJSON features to flat structure
          for (var feature in features) {
            if (feature is Map<String, dynamic>) {
              final properties = feature['properties'] as Map<String, dynamic>?;
              final geometry = feature['geometry'] as Map<String, dynamic>?;
              final coordinates = geometry?['coordinates'] as List?;

              if (properties != null &&
                  coordinates != null &&
                  coordinates.length >= 2) {
                stations.add({
                  'id': properties['Id'],
                  'name': properties['Name'],
                  'country': properties['Country'],
                  'longitude': (coordinates[0] as num).toDouble(),
                  'latitude': (coordinates[1] as num).toDouble(),
                  'continuousHeightsAvailable':
                      properties['ContinuousHeightsAvailable'],
                  'footnote': properties['Footnote'],
                });
              }
            }
          }

          debugPrint(
            '[UK Tidal API] Found ${stations.length} stations in features array',
          );
          return stations;
        } else if (map.containsKey('stations') && map['stations'] is List) {
          final list = List<Map<String, dynamic>>.from(map['stations']);
          debugPrint(
            '[UK Tidal API] Found ${list.length} stations in stations array',
          );
          return list;
        } else if (map.containsKey('data') && map['data'] is List) {
          final list = List<Map<String, dynamic>>.from(map['data']);
          debugPrint(
            '[UK Tidal API] Found ${list.length} stations in data array',
          );
          return list;
        }
      }

      debugPrint('[UK Tidal API] Could not parse stations from response');
      return [];
    } catch (e, stackTrace) {
      debugPrint('[UK Tidal API] Station list error: $e');
      debugPrint('[UK Tidal API] Stack trace: $stackTrace');
      return [];
    }
  }

  final Dio _dio = Dio();
  final String _stormglassBaseUrl =
      'https://api.stormglass.io/v2/tide/extremes/point';

  Future<Map<String, dynamic>> getTideData(
    double lat,
    double lon, {
    String? apiKey,
    bool useDummyData = true,
    String? stationId, // Optional station ID for UK Tidal API
  }) async {
    if (useDummyData) {
      return _getMockTideData(lat, lon);
    }

    // Use Environment Agency if selected (UK only, no API key required)
    if (settings.tidesSource == 'environment_agency') {
      return _getEnvironmentAgencyData(lat, lon);
    }

    // Use UK Tidal API - Discovery if selected (no caching allowed)
    if (settings.tidesSource == 'uk_tidal_api') {
      if (stationId != null && stationId.isNotEmpty) {
        return _getUkTidalDiscoveryDataByStation(
          stationId,
          settings.tidesDiscoveryApiKey,
        );
      }
      return _getUkTidalDiscoveryData(lat, lon, settings.tidesDiscoveryApiKey);
    }

    // Default to Stormglass
    return _getStormglassData(lat, lon, apiKey);
  }

  /// Get tide data for a specific UK Tidal API station ID
  Future<Map<String, dynamic>> _getUkTidalDiscoveryDataByStation(
    String stationId,
    String? apiKey,
  ) async {
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[UK Tidal API] No API key provided. Returning mock data.');
      return _getMockTideData(0, 0);
    }
    try {
      // Get tidal events for this station (current + 6 days)
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(days: 6));
      final eventsUrl =
          'https://admiraltyapi.azure-api.net/uktidalapi/api/V1/Stations/$stationId/TidalEvents';
      final eventsParams = {
        'startDateTime': now.toIso8601String(),
        'endDateTime': end.toIso8601String(),
      };
      debugPrint(
        '[UK Tidal API] Requesting tidal events for station $stationId: $eventsUrl',
      );
      final eventsResp = await _dio.get(
        eventsUrl,
        queryParameters: eventsParams,
        options: Options(headers: {'Ocp-Apim-Subscription-Key': apiKey}),
      );
      debugPrint('[UK Tidal API] Events response: ${eventsResp.statusCode}');
      debugPrint(
        '[UK Tidal API] Events data type: ${eventsResp.data.runtimeType}',
      );
      debugPrint('[UK Tidal API] Events data: ${eventsResp.data}');

      final List<Map<String, dynamic>> extremes = [];
      if (eventsResp.data is List) {
        debugPrint(
          '[UK Tidal API] Processing ${eventsResp.data.length} tidal events',
        );
        for (var event in eventsResp.data) {
          try {
            // API uses capitalized field names: DateTime, Height, EventType
            final time = DateTime.parse(event['DateTime']);
            final height = (event['Height'] as num?)?.toDouble() ?? 0.0;
            final eventType = event['EventType'];

            debugPrint(
              '[UK Tidal API] Parsed - Time: $time, Height: $height, Type: $eventType',
            );

            extremes.add({
              'dt': time.millisecondsSinceEpoch ~/ 1000,
              'date': time.toIso8601String(),
              'height': height,
              'type': eventType == 'HighWater' ? 'High' : 'Low',
            });
          } catch (e) {
            debugPrint('[UK Tidal API] Error parsing event: $e');
          }
        }
        debugPrint('[UK Tidal API] Total extremes parsed: ${extremes.length}');
      }
      // No heights array from this API, so interpolate for chart
      final List<Map<String, dynamic>> heights = [];
      if (extremes.isNotEmpty) {
        final start = DateTime.parse(extremes.first['date']);
        final end = DateTime.parse(extremes.last['date']);
        final duration = end.difference(start);
        for (int hour = 0; hour <= duration.inHours; hour++) {
          final time = start.add(Duration(hours: hour));
          final height = _interpolateHeight(extremes, time);
          heights.add({
            'dt': time.millisecondsSinceEpoch ~/ 1000,
            'date': time.toIso8601String(),
            'height': height,
          });
        }
      }

      // Get station info from saved stations
      final savedStation = isar.savedTideStations.getByStationIdSync(stationId);

      return {
        'status': 200,
        'callCount': 1,
        'lat': savedStation?.lat ?? 0.0,
        'lon': savedStation?.lon ?? 0.0,
        'extremes': extremes,
        'heights': heights,
        'station': {
          'name': savedStation?.name ?? 'Station $stationId',
          'distance': 0.0,
        },
      };
    } catch (e, stackTrace) {
      debugPrint('[UK Tidal API] Exception: $e');
      debugPrint('[UK Tidal API] Stack trace: $stackTrace');
      return _getMockTideData(0, 0);
    }
  }

  Future<Map<String, dynamic>> _getUkTidalDiscoveryData(
    double lat,
    double lon,
    String? apiKey,
  ) async {
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[UK Tidal API] No API key provided. Returning mock data.');
      return _getMockTideData(lat, lon);
    }
    try {
      final stationUrl =
          'https://admiraltyapi.azure-api.net/uktidalapi/api/V1/Stations/Closest';
      final stationParams = {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
      };
      debugPrint(
        '[UK Tidal API] Requesting closest station: $stationUrl $stationParams',
      );
      final stationResp = await _dio.get(
        stationUrl,
        queryParameters: stationParams,
        options: Options(headers: {'Ocp-Apim-Subscription-Key': apiKey}),
      );
      debugPrint(
        '[UK Tidal API] Station response: ${stationResp.statusCode} ${stationResp.data}',
      );
      if (stationResp.data == null || stationResp.data['id'] == null) {
        debugPrint(
          '[UK Tidal API] No valid station found. Returning mock data.',
        );
        return _getMockTideData(lat, lon);
      }
      final stationId = stationResp.data['id'];
      final stationName = stationResp.data['name'] ?? 'UK Tidal API Station';

      // Get tidal events for this station (current + 6 days)
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(days: 6));
      final eventsUrl =
          'https://admiraltyapi.azure-api.net/uktidalapi/api/V1/Stations/$stationId/TidalEvents';
      final eventsParams = {
        'startDateTime': now.toIso8601String(),
        'endDateTime': end.toIso8601String(),
      };
      debugPrint(
        '[UK Tidal API] Requesting tidal events: $eventsUrl $eventsParams',
      );
      final eventsResp = await _dio.get(
        eventsUrl,
        queryParameters: eventsParams,
        options: Options(headers: {'Ocp-Apim-Subscription-Key': apiKey}),
      );
      debugPrint(
        '[UK Tidal API] Events response: ${eventsResp.statusCode} ${eventsResp.data}',
      );
      if (eventsResp.statusCode == 404) {
        debugPrint(
          '[UK Tidal API] 404 from events endpoint. Returning mock data.',
        );
        return _getMockTideData(lat, lon);
      }
      final List<Map<String, dynamic>> extremes = [];
      if (eventsResp.data is List) {
        for (var event in eventsResp.data) {
          try {
            final time = DateTime.parse(event['dateTime']);
            extremes.add({
              'dt': time.millisecondsSinceEpoch ~/ 1000,
              'date': time.toIso8601String(),
              'height': (event['height'] as num?)?.toDouble() ?? 0.0,
              'type': event['eventType'] == 'HighWater' ? 'High' : 'Low',
            });
          } catch (_) {}
        }
      }
      // No heights array from this API, so interpolate for chart
      final List<Map<String, dynamic>> heights = [];
      if (extremes.isNotEmpty) {
        final start = DateTime.parse(extremes.first['date']);
        final end = DateTime.parse(extremes.last['date']);
        final duration = end.difference(start);
        for (int hour = 0; hour <= duration.inHours; hour++) {
          final time = start.add(Duration(hours: hour));
          final height = _interpolateHeight(extremes, time);
          heights.add({
            'dt': time.millisecondsSinceEpoch ~/ 1000,
            'date': time.toIso8601String(),
            'height': height,
          });
        }
      }
      return {
        'status': 200,
        'callCount': 1,
        'lat': lat,
        'lon': lon,
        'extremes': extremes,
        'heights': heights,
        'station': {'name': stationName, 'distance': 0.0},
      };
    } catch (e, stackTrace) {
      debugPrint('[UK Tidal API] Exception: $e');
      debugPrint('[UK Tidal API] Stack trace: $stackTrace');
      return _getMockTideData(lat, lon);
    }
  }

  Future<Map<String, dynamic>> _getStormglassData(
    double lat,
    double lon,
    String? apiKey,
  ) async {
    if (apiKey == null || apiKey.isEmpty) {
      return _getMockTideData(lat, lon);
    }

    try {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 3));

      final response = await _dio.get(
        _stormglassBaseUrl,
        queryParameters: {
          'lat': lat.toString(),
          'lng': lon.toString(),
          'start': now.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
          'datum': settings.tideDatum, // Request data in user's chosen datum
        },
        options: Options(headers: {'Authorization': apiKey}),
      );

      return _convertStormglassToTideData(response.data, lat, lon);
    } catch (e) {
      // Fall back to mock data if API fails
      return _getMockTideData(lat, lon);
    }
  }

  Future<Map<String, dynamic>> _getEnvironmentAgencyData(
    double lat,
    double lon,
  ) async {
    try {
      // UK Environment Agency Flood Monitoring API
      // Search for nearest stations with water level data
      final stationResponse = await _dio.get(
        'https://environment.data.gov.uk/flood-monitoring/id/stations',
        queryParameters: {
          'lat': lat.toStringAsFixed(4),
          'long': lon.toStringAsFixed(4),
          'dist': '50',
        },
      );

      if (stationResponse.data['items'] == null ||
          (stationResponse.data['items'] as List).isEmpty) {
        debugPrint('No Environment Agency stations found nearby');
        return _getMockTideData(lat, lon);
      }

      // Find a station with tide or water level data
      Map<String, dynamic>? selectedStation;
      for (var station in stationResponse.data['items']) {
        if (station['stationReference'] != null) {
          selectedStation = station;
          break;
        }
      }

      if (selectedStation == null) {
        debugPrint('No valid tidal station found');
        return _getMockTideData(lat, lon);
      }

      final stationName = selectedStation['label'] ?? 'Unknown Station';
      final stationRef = selectedStation['stationReference'];

      debugPrint(
        'Using Environment Agency station: $stationName ($stationRef)',
      );

      // Get recent readings for this station
      // Note: Environment Agency uses a simpler date format
      final readingsResponse = await _dio.get(
        'https://environment.data.gov.uk/flood-monitoring/id/stations/$stationRef/readings',
        queryParameters: {'_sorted': '', '_limit': '100'},
      );

      return _convertEnvironmentAgencyToTideData(
        readingsResponse.data,
        lat,
        lon,
        stationName,
      );
    } catch (e, stackTrace) {
      debugPrint('Environment Agency API error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Fall back to mock data if API fails
      return _getMockTideData(lat, lon);
    }
  }

  Map<String, dynamic> _convertEnvironmentAgencyToTideData(
    dynamic data,
    double lat,
    double lon,
    String stationName,
  ) {
    final List<Map<String, dynamic>> extremes = [];
    final List<Map<String, dynamic>> heights = [];

    // Process readings from Environment Agency API
    if (data['items'] != null && (data['items'] as List).isNotEmpty) {
      final readings = data['items'] as List;

      // Convert readings to heights
      for (var reading in readings) {
        try {
          final time = DateTime.parse(reading['dateTime']);
          final value = (reading['value'] as num?)?.toDouble() ?? 0.0;

          heights.add({
            'dt': time.millisecondsSinceEpoch ~/ 1000,
            'date': time.toIso8601String(),
            'height': value,
          });
        } catch (e) {
          debugPrint('Error parsing reading: $e');
          continue;
        }
      }

      // Analyze readings to find high and low tides (extremes)
      if (heights.length >= 3) {
        for (int i = 1; i < heights.length - 1; i++) {
          final prev = heights[i - 1]['height'] as double;
          final current = heights[i]['height'] as double;
          final next = heights[i + 1]['height'] as double;

          // Local maximum (high tide)
          if (current >= prev && current >= next && current > prev) {
            extremes.add({
              'dt': heights[i]['dt'],
              'date': heights[i]['date'],
              'height': current,
              'type': 'High',
            });
          }
          // Local minimum (low tide)
          else if (current <= prev && current <= next && current < prev) {
            extremes.add({
              'dt': heights[i]['dt'],
              'date': heights[i]['date'],
              'height': current,
              'type': 'Low',
            });
          }
        }
      }
    }

    // Generate mock data if real data not available or insufficient
    if (heights.isEmpty || extremes.isEmpty) {
      final now = DateTime.now();
      for (int day = 0; day < 3; day++) {
        final baseTime = now.add(Duration(days: day));
        extremes.addAll([
          {
            'dt':
                baseTime.add(const Duration(hours: 6)).millisecondsSinceEpoch ~/
                1000,
            'date': baseTime.add(const Duration(hours: 6)).toIso8601String(),
            'height': 3.2 + (day * 0.1),
            'type': 'High',
          },
          {
            'dt':
                baseTime
                    .add(const Duration(hours: 12))
                    .millisecondsSinceEpoch ~/
                1000,
            'date': baseTime.add(const Duration(hours: 12)).toIso8601String(),
            'height': 0.8 - (day * 0.1),
            'type': 'Low',
          },
          {
            'dt':
                baseTime
                    .add(const Duration(hours: 18))
                    .millisecondsSinceEpoch ~/
                1000,
            'date': baseTime.add(const Duration(hours: 18)).toIso8601String(),
            'height': 3.5 + (day * 0.1),
            'type': 'High',
          },
          {
            'dt':
                baseTime
                    .add(const Duration(hours: 24))
                    .millisecondsSinceEpoch ~/
                1000,
            'date': baseTime.add(const Duration(hours: 24)).toIso8601String(),
            'height': 0.5 - (day * 0.1),
            'type': 'Low',
          },
        ]);
      }
    }

    // Generate hourly heights if not available or need to fill gaps
    if (heights.isEmpty) {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 12));
      final endTime = now.add(const Duration(days: 3));
      var currentTime = startTime;

      while (currentTime.isBefore(endTime)) {
        final hoursSinceStart =
            currentTime.difference(startTime).inMinutes / 60.0;
        final cyclePosition = (hoursSinceStart % 12) / 12 * 2 * 3.14159;
        final height =
            2.0 +
            1.5 *
                (1 +
                    (cyclePosition < 3.14159 ? 1 : -1) *
                        (1 - (cyclePosition % 3.14159) / 3.14159).abs());

        heights.add({
          'dt': currentTime.millisecondsSinceEpoch ~/ 1000,
          'date': currentTime.toIso8601String(),
          'height': height,
        });

        currentTime = currentTime.add(const Duration(hours: 1));
      }
    }

    return {
      'status': 200,
      'callCount': 1,
      'lat': lat,
      'lon': lon,
      'extremes': extremes,
      'heights': heights,
      'station': {'name': stationName, 'distance': 0.0},
    };
  }

  Map<String, dynamic> _convertStormglassToTideData(
    dynamic data,
    double lat,
    double lon,
  ) {
    final List<Map<String, dynamic>> extremes = [];
    final List<Map<String, dynamic>> heights = [];

    if (data['data'] != null) {
      for (var item in data['data']) {
        final time = DateTime.parse(item['time']);
        final height = item['height'] ?? 0.0;
        final type = item['type'] == 'high' ? 'High' : 'Low';

        extremes.add({
          'dt': time.millisecondsSinceEpoch ~/ 1000,
          'date': time.toIso8601String(),
          'height': (height as num).toDouble(),
          'type': type,
        });
      }
    }

    // Generate hourly heights from extremes
    if (extremes.isNotEmpty) {
      final now = DateTime.now();
      final firstExtreme = DateTime.parse(extremes.first['date']);
      final lastExtreme = DateTime.parse(extremes.last['date']);

      // Start from 12 hours before now OR first extreme (whichever is earlier)
      // This ensures we have data for the current moment
      final start =
          now.subtract(const Duration(hours: 12)).isBefore(firstExtreme)
          ? now.subtract(const Duration(hours: 12))
          : firstExtreme;

      final end = lastExtreme;
      final duration = end.difference(start);

      for (int hour = 0; hour <= duration.inHours; hour++) {
        final time = start.add(Duration(hours: hour));
        final height = _interpolateHeight(extremes, time);
        heights.add({
          'dt': time.millisecondsSinceEpoch ~/ 1000,
          'date': time.toIso8601String(),
          'height': height,
        });
      }
    }

    return {
      'status': 200,
      'callCount': 1,
      'lat': lat,
      'lon': lon,
      'extremes': extremes,
      'heights': heights,
      'station': {'name': 'Stormglass Station', 'distance': 0.0},
    };
  }

  double _interpolateHeight(
    List<Map<String, dynamic>> extremes,
    DateTime time,
  ) {
    if (extremes.isEmpty) return 0.0;

    // Find surrounding extremes and interpolate
    for (int i = 0; i < extremes.length - 1; i++) {
      final current = DateTime.parse(extremes[i]['date']);
      final next = DateTime.parse(extremes[i + 1]['date']);

      if ((time.isAfter(current) || time.isAtSameMomentAs(current)) &&
          (time.isBefore(next) || time.isAtSameMomentAs(next))) {
        final currentHeight = (extremes[i]['height'] as num).toDouble();
        final nextHeight = (extremes[i + 1]['height'] as num).toDouble();
        final totalMinutes = next.difference(current).inMinutes;

        if (totalMinutes == 0) return currentHeight;

        final ratio = time.difference(current).inMinutes / totalMinutes;

        // Use sinusoidal interpolation for more realistic tide curve
        final smoothRatio = (1 - math.cos(ratio * math.pi)) / 2;
        return currentHeight + (nextHeight - currentHeight) * smoothRatio;
      }
    }

    // If before first extreme, extrapolate backward using sinusoidal pattern
    final firstTime = DateTime.parse(extremes.first['date']);
    if (time.isBefore(firstTime) && extremes.length >= 2) {
      final firstHeight = (extremes[0]['height'] as num).toDouble();
      final secondTime = DateTime.parse(extremes[1]['date']);
      final secondHeight = (extremes[1]['height'] as num).toDouble();

      // Assume symmetric tidal pattern
      final cycleDuration = secondTime.difference(firstTime).inMinutes;
      final timeBeforeFirst = firstTime.difference(time).inMinutes;
      final ratio = timeBeforeFirst / cycleDuration;

      // Extrapolate with sinusoidal curve
      final smoothRatio = (1 - math.cos(ratio * math.pi)) / 2;
      return firstHeight + (secondHeight - firstHeight) * smoothRatio;
    }

    // If after last extreme, return last height
    return (extremes.last['height'] as num).toDouble();
  }

  Map<String, dynamic> _getMockTideData(double lat, double lon) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> extremes = [];
    final List<Map<String, dynamic>> heights = [];

    // Generate mock tide data for next 3 days
    for (int day = 0; day < 3; day++) {
      final baseTime = now.add(Duration(days: day));

      // Two high tides and two low tides per day
      extremes.addAll([
        {
          'dt':
              baseTime.add(const Duration(hours: 6)).millisecondsSinceEpoch ~/
              1000,
          'date': baseTime.add(const Duration(hours: 6)).toIso8601String(),
          'height': 3.2 + (day * 0.1),
          'type': 'High',
        },
        {
          'dt':
              baseTime.add(const Duration(hours: 12)).millisecondsSinceEpoch ~/
              1000,
          'date': baseTime.add(const Duration(hours: 12)).toIso8601String(),
          'height': 0.8 - (day * 0.1),
          'type': 'Low',
        },
        {
          'dt':
              baseTime.add(const Duration(hours: 18)).millisecondsSinceEpoch ~/
              1000,
          'date': baseTime.add(const Duration(hours: 18)).toIso8601String(),
          'height': 3.5 + (day * 0.1),
          'type': 'High',
        },
        {
          'dt':
              baseTime.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/
              1000,
          'date': baseTime.add(const Duration(hours: 24)).toIso8601String(),
          'height': 0.5 - (day * 0.1),
          'type': 'Low',
        },
      ]);
    }

    // Generate hourly heights starting from 12 hours ago to 3 days ahead
    // This ensures we have data before and after current time for proper interpolation
    final startTime = now.subtract(const Duration(hours: 12));
    final endTime = now.add(const Duration(days: 3));
    var currentTime = startTime;

    while (currentTime.isBefore(endTime)) {
      // Calculate sine wave pattern for tide height
      final hoursSinceStart =
          currentTime.difference(startTime).inMinutes / 60.0;
      // Two tides per day = 12 hour cycle
      final cyclePosition = (hoursSinceStart % 12) / 12 * 2 * 3.14159;
      final height =
          2.0 +
          1.5 *
              (1 +
                  (cyclePosition < 3.14159 ? 1 : -1) *
                      (1 - (cyclePosition % 3.14159) / 3.14159).abs());

      heights.add({
        'dt': currentTime.millisecondsSinceEpoch ~/ 1000,
        'date': currentTime.toIso8601String(),
        'height': height,
      });

      currentTime = currentTime.add(const Duration(hours: 1));
    }

    return {
      'status': 200,
      'callCount': 1,
      'lat': lat,
      'lon': lon,
      'extremes': extremes,
      'heights': heights,
      'station': {'name': 'Nearby Station', 'distance': 5.2},
    };
  }

  String getNextTideInfo(Map<String, dynamic> tideData) {
    final extremes = tideData['extremes'] as List<dynamic>;
    if (extremes.isEmpty) return 'No tide data available';

    final now = DateTime.now();
    for (var extreme in extremes) {
      final tideTime = DateTime.parse(extreme['date'] as String);
      if (tideTime.isAfter(now)) {
        final type = (extreme['type'] as String).toLowerCase();
        final height = (extreme['height'] as num).toStringAsFixed(1);
        final duration = tideTime.difference(now);
        String timeStr;
        if (duration.inHours > 0) {
          timeStr = '${duration.inHours}h ${duration.inMinutes % 60}m';
        } else {
          timeStr = '${duration.inMinutes}m';
        }
        return '${type.substring(0, 1).toUpperCase()}${type.substring(1)} tide in $timeStr ($height m)';
      }
    }
    return 'No upcoming tides';
  }

  double getCurrentTideHeight(Map<String, dynamic> tideData) {
    final heights = tideData['heights'] as List<dynamic>;
    if (heights.isEmpty) return 0.0;

    final now = DateTime.now();

    // Find the closest data points around current time
    for (int i = 0; i < heights.length - 1; i++) {
      final current = DateTime.parse(heights[i]['date'] as String);
      final next = DateTime.parse(heights[i + 1]['date'] as String);

      // Check if current time is between these two points
      if ((now.isAfter(current) || now.isAtSameMomentAs(current)) &&
          (now.isBefore(next) || now.isAtSameMomentAs(next))) {
        // Interpolate between current and next
        final currentHeight = (heights[i]['height'] as num).toDouble();
        final nextHeight = (heights[i + 1]['height'] as num).toDouble();
        final totalMinutes = next.difference(current).inMinutes;

        if (totalMinutes == 0) return currentHeight;

        final ratio = now.difference(current).inMinutes / totalMinutes;
        return currentHeight + (nextHeight - currentHeight) * ratio;
      }
    }

    // If we're before all data points, return first height
    final firstTime = DateTime.parse(heights.first['date'] as String);
    if (now.isBefore(firstTime)) {
      return (heights.first['height'] as num).toDouble();
    }

    // If we're after all data points, return last height
    return (heights.last['height'] as num).toDouble();
  }
}
