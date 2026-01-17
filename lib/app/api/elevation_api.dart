import 'package:dio/dio.dart';

// Using Open-Elevation API (Free and open-source)
// Public instance: https://open-elevation.com/
// Or self-hosted: https://github.com/Jorl17/open-elevation
class ElevationAPI {
  final Dio _dio = Dio();
  static const String _baseUrl = 'https://api.open-elevation.com/api/v1/lookup';

  Future<Map<String, dynamic>> getElevationData(
    double lat,
    double lon, {
    String? apiKey,
    bool useDummyData = true,
  }) async {
    if (useDummyData) {
      return _getMockElevationData(lat, lon);
    }

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {'locations': '$lat,$lon'},
        options: Options(
          headers: apiKey != null && apiKey.isNotEmpty
              ? {'Authorization': 'Bearer $apiKey'}
              : {},
        ),
      );

      return _convertOpenElevationData(response.data, lat, lon);
    } catch (e) {
      // Fall back to mock data if API fails
      return _getMockElevationData(lat, lon);
    }
  }

  Map<String, dynamic> _convertOpenElevationData(
    dynamic data,
    double lat,
    double lon,
  ) {
    double elevation = 0.0;

    if (data['results'] != null && (data['results'] as List).isNotEmpty) {
      elevation = (data['results'][0]['elevation'] ?? 0.0).toDouble();
    }

    return {
      'status': 200,
      'lat': lat,
      'lon': lon,
      'elevation': elevation, // meters above sea level
      'elevationFt': elevation * 3.28084, // feet above sea level
      'source': 'Open-Elevation API',
    };
  }

  Map<String, dynamic> _getMockElevationData(double lat, double lon) {
    // Generate mock elevation based on latitude
    // Higher latitudes tend to have more varied terrain
    double baseElevation = 100.0;

    // Add some variation based on coordinates
    final latVariation = (lat.abs() * 10) % 500;
    final lonVariation = (lon.abs() * 10) % 300;

    final elevation = baseElevation + latVariation + lonVariation;

    return {
      'status': 200,
      'lat': lat,
      'lon': lon,
      'elevation': elevation.roundToDouble(),
      'elevationFt': (elevation * 3.28084).roundToDouble(),
      'source': 'Mock Data',
    };
  }

  String getElevationDescription(double elevation) {
    if (elevation < 0) return 'Below sea level';
    if (elevation < 100) return 'Near sea level';
    if (elevation < 500) return 'Low elevation';
    if (elevation < 1000) return 'Moderate elevation';
    if (elevation < 2000) return 'High elevation';
    if (elevation < 3000) return 'Very high elevation';
    return 'Mountain elevation';
  }

  String getPressureEffect(double elevation) {
    // Atmospheric pressure decreases by approximately 12% per 1000m
    final pressureReduction = (elevation / 1000) * 12;
    if (pressureReduction < 5) return 'Minimal pressure change';
    if (pressureReduction < 10) return 'Slight pressure reduction';
    if (pressureReduction < 20) return 'Noticeable pressure reduction';
    return 'Significant pressure reduction';
  }

  String getBoilingPoint(double elevation) {
    // Water boiling point decreases by approximately 1°C per 300m
    final boilingPoint = 100 - (elevation / 300);
    return '${boilingPoint.toStringAsFixed(1)}°C';
  }
}
