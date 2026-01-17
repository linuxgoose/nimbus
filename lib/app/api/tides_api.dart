import 'package:dio/dio.dart';

// Using Stormglass.io API (Free tier: 50 requests/day)
// Get your free API key at: https://stormglass.io/
class TidesAPI {
  final Dio _dio = Dio();
  static const String _baseUrl =
      'https://api.stormglass.io/v2/tide/extremes/point';

  Future<Map<String, dynamic>> getTideData(
    double lat,
    double lon, {
    String? apiKey,
    bool useDummyData = true,
  }) async {
    if (useDummyData || apiKey == null || apiKey.isEmpty) {
      return _getMockTideData(lat, lon);
    }

    try {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 3));

      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'lat': lat.toString(),
          'lng': lon.toString(),
          'start': now.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
        options: Options(headers: {'Authorization': apiKey}),
      );

      return _convertStormglassToTideData(response.data, lat, lon);
    } catch (e) {
      // Fall back to mock data if API fails
      return _getMockTideData(lat, lon);
    }
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
          'height': height,
          'type': type,
        });
      }
    }

    // Generate hourly heights from extremes
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
      'station': {'name': 'Stormglass Station', 'distance': 0.0},
    };
  }

  double _interpolateHeight(
    List<Map<String, dynamic>> extremes,
    DateTime time,
  ) {
    // Find surrounding extremes and interpolate
    for (int i = 0; i < extremes.length - 1; i++) {
      final current = DateTime.parse(extremes[i]['date']);
      final next = DateTime.parse(extremes[i + 1]['date']);

      if (time.isAfter(current) && time.isBefore(next)) {
        final currentHeight = extremes[i]['height'] as num;
        final nextHeight = extremes[i + 1]['height'] as num;
        final ratio =
            time.difference(current).inMinutes /
            next.difference(current).inMinutes;
        return currentHeight + (nextHeight - currentHeight) * ratio;
      }
    }

    return extremes.isNotEmpty ? extremes.first['height'] : 0.0;
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

      // Hourly heights
      for (int hour = 0; hour < 24; hour++) {
        final time = baseTime.add(Duration(hours: hour));
        final height = 2.0 + 1.5 * (1 + (hour % 12 < 6 ? 1 : -1) * 0.8);
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
        final type = extreme['type'] as String;
        final height = (extreme['height'] as num).toStringAsFixed(1);
        final duration = tideTime.difference(now);
        String timeStr;
        if (duration.inHours > 0) {
          timeStr = '${duration.inHours}h ${duration.inMinutes % 60}m';
        } else {
          timeStr = '${duration.inMinutes}m';
        }
        return '$type tide in $timeStr ($height m)';
      }
    }
    return 'No upcoming tides';
  }

  double getCurrentTideHeight(Map<String, dynamic> tideData) {
    final heights = tideData['heights'] as List<dynamic>;
    if (heights.isEmpty) return 0.0;

    final now = DateTime.now();
    for (int i = 0; i < heights.length - 1; i++) {
      final current = DateTime.parse(heights[i]['date'] as String);
      final next = DateTime.parse(heights[i + 1]['date'] as String);
      if (now.isAfter(current) && now.isBefore(next)) {
        // Interpolate between current and next
        final currentHeight = heights[i]['height'] as num;
        final nextHeight = heights[i + 1]['height'] as num;
        final ratio =
            now.difference(current).inMinutes /
            next.difference(current).inMinutes;
        return currentHeight + (nextHeight - currentHeight) * ratio;
      }
    }
    return (heights.first['height'] as num).toDouble();
  }
}
