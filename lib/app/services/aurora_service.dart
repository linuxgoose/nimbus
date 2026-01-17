import 'dart:convert';
import 'package:http/http.dart' as http;

class AuroraService {
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
