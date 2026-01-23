import 'dart:convert';
import 'package:dio/dio.dart';

/// Service for natural disaster and Earth event data
class EarthEventsService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // USGS Earthquakes (already implemented in aurora_service, keeping here for organization)
  static Future<List<Map<String, dynamic>>?> getRecentEarthquakes({
    double? latitude,
    double? longitude,
    double radiusKm = 1000,
    double minMagnitude = 2.5,
  }) async {
    try {
      String url;
      if (latitude != null && longitude != null) {
        url =
            'https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson'
            '&latitude=$latitude&longitude=$longitude&maxradiuskm=$radiusKm'
            '&minmagnitude=$minMagnitude&orderby=time&limit=20';
      } else {
        url =
            'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson';
      }

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        // Dio handles JSON automatically if content-type is json
        // If USGS returns string, we might need manual decode, but usually it works
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;
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
            'cdi': props['cdi'],
            'alert': props['alert'],
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

  // NWS Weather Alerts (US only)
  static Future<List<Map<String, dynamic>>?> getNWSAlerts({
    required double latitude,
    required double longitude,
  }) async {
    try {
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
            'severity': props['severity'],
            'certainty': props['certainty'],
            'urgency': props['urgency'],
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

  // NASA FIRMS - Active Fires (Wildfires)
  static Future<List<Map<String, dynamic>>?> getActiveFires({
    required double latitude,
    required double longitude,
    double radiusDegrees = 5.0,
    int daysBack = 1,
  }) async {
    try {
      // FIRMS requires registration for API key, using public CSV endpoint
      // Map key would need to be stored in settings for production use
      final apiKey = 'YOUR_FIRMS_API_KEY'; // User would need to add this

      // Using VIIRS data (more recent than MODIS)
      final url =
          'https://firms.modaps.eosdis.nasa.gov/api/area/csv/$apiKey/VIIRS_NOAA20_NRT/'
          '${latitude - radiusDegrees},${longitude - radiusDegrees},'
          '${latitude + radiusDegrees},${longitude + radiusDegrees}/$daysBack';

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final lines = response.data.toString().split('\n');
        if (lines.isEmpty) return [];

        final headers = lines[0].split(',');
        final fires = <Map<String, dynamic>>[];

        for (var i = 1; i < lines.length; i++) {
          if (lines[i].trim().isEmpty) continue;
          final values = lines[i].split(',');
          if (values.length < headers.length) continue;

          final lat = double.tryParse(values[0]) ?? 0.0;
          final lon = double.tryParse(values[1]) ?? 0.0;
          final brightness = double.tryParse(values[2]) ?? 0.0;
          final confidence = values[8];
          final frp =
              double.tryParse(values[10]) ?? 0.0; // Fire Radiative Power

          fires.add({
            'latitude': lat,
            'longitude': lon,
            'brightness': brightness,
            'confidence': confidence,
            'frp': frp,
            'acq_date': values[5],
            'acq_time': values[6],
            'severity': _getFireSeverity(frp, confidence),
            'color': _getFireColor(frp),
          });
        }

        return fires;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // GDACS - Global Disaster Alerts
  static Future<List<Map<String, dynamic>>?> getGDACSAlerts() async {
    try {
      final response = await _dio.get(
        'https://www.gdacs.org/gdacsapi/api/events/geteventlist/MAP',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final features = data['features'] as List?;

        if (features == null || features.isEmpty) return [];

        final alerts = <Map<String, dynamic>>[];

        for (var feature in features) {
          final props = feature['properties'];
          final geometry = feature['geometry'];

          alerts.add({
            'eventtype': props['eventtype'], // EQ, TC, FL, VO, etc.
            'eventname': props['eventname'],
            'description': props['description'],
            'htmldescription': props['htmldescription'],
            'severity': props['severity'],
            'alertlevel': props['alertlevel'], // Green, Orange, Red
            'country': props['country'],
            'fromdate': props['fromdate'],
            'todate': props['todate'],
            'latitude': geometry?['coordinates']?[1],
            'longitude': geometry?['coordinates']?[0],
            'url': props['url'],
            'color': _getGDACSColor(props['alertlevel']),
            'icon': _getGDACSIcon(props['eventtype']),
          });
        }

        return alerts;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // NASA EONET - Earth Observatory Natural Event Tracker
  static Future<List<Map<String, dynamic>>?> getNaturalEvents({
    int days = 30,
    String? category, // wildfires, severeStorms, volcanoes, floods, etc.
  }) async {
    try {
      var url =
          'https://eonet.gsfc.nasa.gov/api/v3/events?days=$days&status=open';
      if (category != null) {
        url += '&category=$category';
      }

      final response = await _dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        final events = data['events'] as List?;

        if (events == null || events.isEmpty) return [];

        final naturalEvents = <Map<String, dynamic>>[];

        for (var event in events) {
          final categories = event['categories'] as List;
          final geometries = event['geometry'] as List;

          // Get the most recent geometry
          final latestGeometry = geometries.isNotEmpty ? geometries.last : null;
          final coords = latestGeometry?['coordinates'];

          naturalEvents.add({
            'id': event['id'],
            'title': event['title'],
            'description': event['description'],
            'category': categories.isNotEmpty
                ? categories[0]['title']
                : 'Unknown',
            'categoryId': categories.isNotEmpty ? categories[0]['id'] : '',
            'date': latestGeometry?['date'],
            'latitude': coords != null && coords.length > 1 ? coords[1] : null,
            'longitude': coords != null && coords.length > 0 ? coords[0] : null,
            'link': event['link'],
            'color': _getEventCategoryColor(
              categories.isNotEmpty ? categories[0]['id'] : '',
            ),
            'icon': _getEventCategoryIcon(
              categories.isNotEmpty ? categories[0]['id'] : '',
            ),
          });
        }

        return naturalEvents;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Helper methods for severity and color coding
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
    if (magnitude >= 7.0) return '#FF0000'; // Red
    if (magnitude >= 6.0) return '#FF6600'; // Orange
    if (magnitude >= 5.0) return '#FFAA00'; // Yellow
    if (magnitude >= 4.0) return '#FFDD00'; // Light Yellow
    return '#00AA00'; // Green
  }

  static String _getNWSSeverityColor(String? severity) {
    if (severity == null) return '#666666';
    switch (severity.toLowerCase()) {
      case 'extreme':
        return '#FF0000';
      case 'severe':
        return '#FF6600';
      case 'moderate':
        return '#FFAA00';
      case 'minor':
        return '#FFDD00';
      default:
        return '#00AA00';
    }
  }

  static String _getFireSeverity(double frp, String confidence) {
    if (confidence == 'h') {
      if (frp > 100) return 'Extreme';
      if (frp > 50) return 'High';
      return 'Moderate';
    } else if (confidence == 'n') {
      return 'Moderate';
    }
    return 'Low';
  }

  static String _getFireColor(double frp) {
    if (frp > 100) return '#FF0000'; // Red
    if (frp > 50) return '#FF6600'; // Orange
    if (frp > 20) return '#FFAA00'; // Yellow
    return '#FFDD00'; // Light Yellow
  }

  static String _getGDACSColor(String? alertLevel) {
    if (alertLevel == null) return '#666666';
    switch (alertLevel.toLowerCase()) {
      case 'red':
        return '#FF0000';
      case 'orange':
        return '#FF6600';
      case 'green':
        return '#00AA00';
      default:
        return '#666666';
    }
  }

  static String _getGDACSIcon(String? eventType) {
    if (eventType == null) return 'alert';
    switch (eventType.toUpperCase()) {
      case 'EQ':
        return 'waves'; // Earthquake
      case 'TC':
        return 'wind'; // Tropical Cyclone
      case 'FL':
        return 'droplets'; // Flood
      case 'VO':
        return 'flame'; // Volcano
      case 'DR':
        return 'cloud-drizzle'; // Drought
      default:
        return 'alert-triangle';
    }
  }

  static String _getEventCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'wildfires':
        return '#FF6600';
      case 'severeStorms':
        return '#4A90E2';
      case 'volcanoes':
        return '#FF0000';
      case 'floods':
        return '#0066CC';
      case 'drought':
        return '#CC6600';
      case 'landslides':
        return '#996633';
      case 'seaLakeIce':
        return '#00CCFF';
      case 'snow':
        return '#CCCCFF';
      default:
        return '#666666';
    }
  }

  static String _getEventCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'wildfires':
        return 'flame';
      case 'severeStorms':
        return 'cloud-lightning';
      case 'volcanoes':
        return 'triangle-alert';
      case 'floods':
        return 'droplets';
      case 'drought':
        return 'sun';
      case 'landslides':
        return 'mountain';
      case 'seaLakeIce':
        return 'snowflake';
      case 'snow':
        return 'snowflake';
      default:
        return 'alert-circle';
    }
  }
}
