import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:nimbus/app/services/metno_service.dart';
import 'package:nimbus/main.dart';

/// Hybrid weather service that intelligently combines Open-Meteo and MET Norway
/// Uses the best data source for each feature
class HybridWeatherService {
  /// Determine if location should use MET Norway
  /// Considers both geographic region and user preference
  static bool _shouldUseMetNo(double lat, double lon) {
    // If user has enabled preference override, always use MET Norway in hybrid mode
    if (settings.preferMetNoInHybrid) {
      debugPrint('👤 User prefers MET Norway - override enabled');
      return true;
    }

    // Otherwise check if in Nordic region
    return _isNordicRegion(lat, lon);
  }

  /// Determine if location is in Nordic region (better MET Norway coverage)
  static bool _isNordicRegion(double lat, double lon) {
    // Norway, Sweden, Finland, Denmark, Iceland
    // More precise bounds to exclude UK/Ireland: 55°N-72°N, 4°E-32°E
    // Iceland exception: 63°N-67°N, 25°W-13°W

    // Iceland
    if (lat >= 63 && lat <= 67 && lon >= -25 && lon <= -13) {
      return true;
    }

    // Mainland Nordic (exclude western areas to avoid UK/Ireland)
    if (lat >= 55 && lat <= 72 && lon >= 4 && lon <= 32) {
      return true;
    }

    return false;
  }

  /// Get weather data using hybrid approach
  /// - Use MET Norway for Nordic region or when user prefers it
  /// - Use Open-Meteo for global coverage
  /// - Combine best features from both
  static Future<Map<String, dynamic>?> getWeatherData({
    required double lat,
    required double lon,
    int? altitude,
  }) async {
    final useMetNo = _shouldUseMetNo(lat, lon);
    final isNordic = _isNordicRegion(lat, lon);

    debugPrint(
      '🌐 Hybrid Service: Location ${isNordic ? "IS" : "IS NOT"} in Nordic region',
    );
    if (settings.preferMetNoInHybrid && !isNordic) {
      debugPrint(
        '🔧 Override: Using MET Norway outside Nordic region per user preference',
      );
    }

    Map<String, dynamic>? primaryData;

    if (settings.weatherDataSource == 'metno') {
      // MET Norway only
      debugPrint('🇳🇴 Using MET Norway as primary source');
      final metnoData = await MetNoService.getLocationForecast(
        lat: lat,
        lon: lon,
        altitude: altitude,
      );

      if (metnoData != null) {
        debugPrint('📦 MET Norway raw response received');
        primaryData = await MetNoService.convertToOpenMeteoFormat(
          metnoData,
          lat: lat,
          lon: lon,
        );
        if (primaryData == null) {
          debugPrint('⚠️ MET Norway data conversion failed');
        }
      } else {
        debugPrint('⚠️ MET Norway returned null response');
      }
    } else if (settings.weatherDataSource == 'openmeteo') {
      // Open-Meteo only (current implementation)
      debugPrint('🌍 Using Open-Meteo as primary source');
      // Return null to use existing Open-Meteo fetching
      return null;
    } else {
      // Hybrid mode
      if (useMetNo) {
        debugPrint('🔀 Hybrid: Using MET Norway for location');
        final metnoData = await MetNoService.getLocationForecast(
          lat: lat,
          lon: lon,
          altitude: altitude,
        );

        if (metnoData != null) {
          debugPrint('📦 MET Norway raw response received for hybrid mode');
          primaryData = await MetNoService.convertToOpenMeteoFormat(
            metnoData,
            lat: lat,
            lon: lon,
          );
          if (primaryData == null) {
            debugPrint('⚠️ MET Norway conversion failed in hybrid mode');
          }
        } else {
          debugPrint('⚠️ MET Norway returned null in hybrid mode');
        }

        // Try to enhance with Nowcast for precipitation
        final nowcast = await MetNoService.getNowcast(lat: lat, lon: lon);
        if (nowcast != null && primaryData != null) {
          debugPrint('✨ Enhanced with MET Nowcast data');
          primaryData = _enhanceWithNowcast(primaryData, nowcast);
        }
      } else {
        debugPrint('🔀 Hybrid: Using Open-Meteo for global location');
        // Use Open-Meteo for locations outside Nordic region
        return null;
      }
    }

    return primaryData;
  }

  /// Get weather alerts using best available source
  static Future<List<Map<String, dynamic>>> getWeatherAlerts({
    required double lat,
    required double lon,
  }) async {
    final useMetNo = _shouldUseMetNo(lat, lon);
    final alerts = <Map<String, dynamic>>[];

    // Try MET Norway MetAlerts when appropriate
    if (useMetNo &&
        (settings.weatherDataSource == 'metno' ||
            settings.weatherDataSource == 'hybrid')) {
      debugPrint('🚨 Fetching official alerts from MET Norway');
      final metAlerts = await MetNoService.getMetAlerts(lat: lat, lon: lon);

      if (metAlerts != null) {
        debugPrint('📦 MetAlerts data type: ${metAlerts.runtimeType}');
        final features = metAlerts['features'] as List<dynamic>?;
        debugPrint('📋 Features count: ${features?.length ?? 0}');

        if (features != null && features.isNotEmpty) {
          for (var feature in features) {
            final geometry = feature['geometry'] as Map<String, dynamic>?;
            final properties = feature['properties'] as Map<String, dynamic>?;

            if (properties != null && _isAlertRelevant(geometry, lat, lon)) {
              alerts.add(_convertMetAlert(properties));
            }
          }
          debugPrint('✅ Found ${alerts.length} relevant MET Norway alerts');
        } else {
          debugPrint('ℹ️ No MET Norway alerts for this region');
        }
      }
    }

    // Fall back to Open-Meteo alerts if needed
    // (Open-Meteo alerts will be fetched by existing code)

    return alerts;
  }

  /// Check if alert geometry is relevant to location
  /// Uses distance-based filtering with 150km radius
  static bool _isAlertRelevant(
    Map<String, dynamic>? geometry,
    double lat,
    double lon,
  ) {
    if (geometry == null) return false; // Skip alerts without geometry

    final type = geometry['type'] as String?;

    // Extract coordinates from geometry
    if (type == 'Polygon') {
      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates != null && coordinates.isNotEmpty) {
        final ring = coordinates[0] as List<dynamic>?;
        if (ring != null) {
          // Check if user location is near any polygon points
          return _isLocationNearPolygon(ring, lat, lon);
        }
      }
    } else if (type == 'MultiPolygon') {
      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates != null && coordinates.isNotEmpty) {
        for (var polygon in coordinates) {
          final ring = (polygon as List<dynamic>?)?[0] as List<dynamic>?;
          if (ring != null && _isLocationNearPolygon(ring, lat, lon)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Check if location is within 150km of any polygon point
  static bool _isLocationNearPolygon(
    List<dynamic> ring,
    double lat,
    double lon,
  ) {
    const maxDistanceKm = 150.0; // Alert relevance radius

    for (var point in ring) {
      if (point is List && point.length >= 2) {
        final pLon = (point[0] as num).toDouble();
        final pLat = (point[1] as num).toDouble();

        final distance = _calculateDistance(lat, lon, pLat, pLon);
        if (distance <= maxDistanceKm) {
          return true;
        }
      }
    }

    return false;
  }

  /// Calculate distance between two points using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Convert MET Norway alert to standard format
  static Map<String, dynamic> _convertMetAlert(
    Map<String, dynamic> properties,
  ) {
    // MET Norway uses CAP (Common Alerting Protocol) format
    final event = properties['event'] as String? ?? 'Unknown';
    final severity = properties['severity'] as String? ?? 'Unknown';
    final description = properties['description'] as String? ?? '';
    final onset = properties['onset'] as String?;
    final expires = properties['expires'] as String?;

    return {
      'event': event,
      'severity': _convertMetSeverity(severity),
      'description': description,
      'onset': onset,
      'expires': expires,
      'source': 'MET Norway',
    };
  }

  /// Convert MET Norway severity to standard format
  static String _convertMetSeverity(String metSeverity) {
    switch (metSeverity.toLowerCase()) {
      case 'extreme':
        return 'Extreme';
      case 'severe':
        return 'Severe';
      case 'moderate':
        return 'Moderate';
      case 'minor':
        return 'Minor';
      default:
        return 'Unknown';
    }
  }

  /// Enhance forecast with Nowcast precipitation data
  static Map<String, dynamic> _enhanceWithNowcast(
    Map<String, dynamic> forecast,
    Map<String, dynamic> nowcast,
  ) {
    try {
      final hourly = forecast['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return forecast;

      final properties = nowcast['properties'] as Map<String, dynamic>?;
      final timeseries = properties?['timeseries'] as List<dynamic>?;

      if (timeseries == null || timeseries.isEmpty) return forecast;

      final precipitation = hourly['precipitation'] as List<dynamic>?;
      if (precipitation == null) return forecast;

      // Update first 2 hours with more accurate Nowcast data
      for (var i = 0; i < timeseries.length && i < 2; i++) {
        final entry = timeseries[i] as Map<String, dynamic>?;
        final data = entry?['data'] as Map<String, dynamic>?;
        final next1h = data?['next_1_hours'] as Map<String, dynamic>?;
        final details = next1h?['details'] as Map<String, dynamic>?;
        final precipAmount = details?['precipitation_amount'] as num?;

        if (precipAmount != null && i < precipitation.length) {
          precipitation[i] = precipAmount.toDouble();
        }
      }

      return forecast;
    } catch (e) {
      debugPrint('⚠️ Error enhancing with Nowcast: $e');
      return forecast;
    }
  }

  /// Get radar images using best source
  static Future<List<String>?> getRadarImages() async {
    // For Nordic region, try MET Norway radar
    if (settings.weatherDataSource == 'metno' ||
        settings.weatherDataSource == 'hybrid') {
      final images = await MetNoService.getRadarImages();
      if (images != null && images.isNotEmpty) {
        debugPrint('🌧️ Using MET Norway radar images');
        return images;
      }
    }

    // Fall back to RainViewer (existing implementation)
    debugPrint('🌧️ Falling back to RainViewer radar');
    return null;
  }
}
