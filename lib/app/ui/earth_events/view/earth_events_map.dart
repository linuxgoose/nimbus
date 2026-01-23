import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:get/get.dart' hide Response;
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nimbus/app/controller/controller.dart';

class EarthEventsMapPage extends StatefulWidget {
  final List<Map<String, dynamic>>? earthquakes;
  final List<Map<String, dynamic>>? wildfires;
  final List<Map<String, dynamic>>? gdacsAlerts;
  final List<Map<String, dynamic>>? eonetEvents;

  const EarthEventsMapPage({
    super.key,
    this.earthquakes,
    this.wildfires,
    this.gdacsAlerts,
    this.eonetEvents,
  });

  @override
  State<EarthEventsMapPage> createState() => _EarthEventsMapPageState();
}

class _EarthEventsMapPageState extends State<EarthEventsMapPage> {
  late final MapController _mapController;
  final weatherController = Get.find<WeatherController>();
  final Future<CacheStore> _cacheStoreFuture = _getCacheStore();

  bool _showEarthquakes = true;
  bool _showWildfires = true;
  bool _showGDACS = true;
  bool _showEONET = true;

  static Future<CacheStore> _getCacheStore() async {
    final dir = await getTemporaryDirectory();
    return FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    debugPrint('Building markers...');
    debugPrint('Earthquakes: ${widget.earthquakes?.length ?? 0}');
    debugPrint('Wildfires: ${widget.wildfires?.length ?? 0}');
    debugPrint('GDACS: ${widget.gdacsAlerts?.length ?? 0}');
    debugPrint('EONET: ${widget.eonetEvents?.length ?? 0}');

    // Add earthquake markers
    if (_showEarthquakes && widget.earthquakes != null) {
      for (var quake in widget.earthquakes!) {
        final lat = (quake['latitude'] as num?)?.toDouble();
        final lon = (quake['longitude'] as num?)?.toDouble();
        debugPrint('Earthquake at: $lat, $lon');
        final magnitude = quake['magnitude'] ?? 0.0;
        final place = quake['place'] ?? 'Unknown';
        final colorHex = quake['color'] ?? '#FF0000';
        final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

        if (lat != null && lon != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showEventDetails(
                  'Earthquake',
                  place,
                  'Magnitude: ${magnitude.toStringAsFixed(1)}',
                  color,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      magnitude.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    // Add wildfire markers
    if (_showWildfires && widget.wildfires != null) {
      for (var fire in widget.wildfires!) {
        final lat = (fire['latitude'] as num?)?.toDouble();
        final lon = (fire['longitude'] as num?)?.toDouble();
        final brightness = fire['brightness'] ?? 0.0;
        final frp = fire['frp'] ?? 0.0;
        final colorHex = fire['color'] ?? '#FF6600';
        final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

        if (lat != null && lon != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showEventDetails(
                  'Wildfire',
                  'Fire detected',
                  'Brightness: ${brightness.toStringAsFixed(0)}K\nFRP: ${frp.toStringAsFixed(0)} MW',
                  color,
                ),
                child: Icon(
                  LucideIcons.flame,
                  color: color,
                  size: 24,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
          );
        }
      }
    }

    // Add GDACS markers
    if (_showGDACS && widget.gdacsAlerts != null) {
      for (var alert in widget.gdacsAlerts!) {
        final lat = (alert['latitude'] as num?)?.toDouble();
        final lon = (alert['longitude'] as num?)?.toDouble();
        final eventType = alert['eventtype'] ?? 'Unknown';
        final name = alert['eventname'] ?? 'Unknown';
        final severity = alert['severity'] ?? 'Unknown';
        final iconName = alert['icon'] ?? 'alert-circle';
        final colorHex = alert['color'] ?? '#FF0000';
        final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

        if (lat != null && lon != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showEventDetails(
                  eventType,
                  name,
                  'Severity: $severity',
                  color,
                ),
                child: Icon(
                  _getIconData(iconName),
                  color: color,
                  size: 24,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
          );
        }
      }
    }

    // Add EONET markers
    if (_showEONET && widget.eonetEvents != null) {
      for (var event in widget.eonetEvents!) {
        final lat = (event['latitude'] as num?)?.toDouble();
        final lon = (event['longitude'] as num?)?.toDouble();
        final title = event['title'] ?? 'Unknown';
        final category = event['category'] ?? 'Unknown';
        final iconName = event['icon'] ?? 'alert-circle';
        final colorHex = event['color'] ?? '#0066CC';
        final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

        debugPrint('EONET event: $title at $lat, $lon');

        if (lat != null && lon != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lon),
              width: 30,
              height: 30,
              child: GestureDetector(
                onTap: () => _showEventDetails(category, title, '', color),
                child: Icon(
                  _getIconData(iconName),
                  color: color,
                  size: 24,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                ),
              ),
            ),
          );
        }
      }
    }

    debugPrint('Total markers created: ${markers.length}');
    return markers;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'waves':
        return LucideIcons.waves;
      case 'wind':
        return LucideIcons.wind;
      case 'droplets':
        return LucideIcons.droplets;
      case 'flame':
        return LucideIcons.flame;
      case 'cloud-drizzle':
        return LucideIcons.cloudDrizzle;
      case 'alert-triangle':
        return LucideIcons.triangleAlert;
      case 'cloud-lightning':
        return LucideIcons.cloudLightning;
      case 'mountain':
        return LucideIcons.mountain;
      case 'snowflake':
        return LucideIcons.snowflake;
      case 'sun':
        return LucideIcons.sun;
      case 'alert-circle':
        return LucideIcons.circleAlert;
      default:
        return LucideIcons.circleAlert;
    }
  }

  void _showEventDetails(
    String type,
    String title,
    String details,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(LucideIcons.mapPin, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(details, style: context.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final location = weatherController.location;
      final lat = location.lat ?? 0.0;
      final lon = location.lon ?? 0.0;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Earth Events Map'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.listFilter),
              onSelected: (value) {
                setState(() {
                  switch (value) {
                    case 'earthquakes':
                      _showEarthquakes = !_showEarthquakes;
                      break;
                    case 'wildfires':
                      _showWildfires = !_showWildfires;
                      break;
                    case 'gdacs':
                      _showGDACS = !_showGDACS;
                      break;
                    case 'eonet':
                      _showEONET = !_showEONET;
                      break;
                  }
                });
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'earthquakes',
                  checked: _showEarthquakes,
                  child: const Text('Earthquakes'),
                ),
                CheckedPopupMenuItem(
                  value: 'wildfires',
                  checked: _showWildfires,
                  child: const Text('Wildfires'),
                ),
                CheckedPopupMenuItem(
                  value: 'gdacs',
                  checked: _showGDACS,
                  child: const Text('GDACS Alerts'),
                ),
                CheckedPopupMenuItem(
                  value: 'eonet',
                  checked: _showEONET,
                  child: const Text('NASA EONET'),
                ),
              ],
            ),
          ],
        ),
        body: FutureBuilder<CacheStore>(
          future: _cacheStoreFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading map',
                      style: context.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: context.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(lat, lon),
                initialZoom: 4,
                minZoom: 2,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cirrusweather.nimbus',
                  tileProvider: CachedTileProvider(
                    store: snapshot.data!,
                    maxStale: const Duration(days: 30),
                  ),
                ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final location = weatherController.location;
            final lat = location.lat ?? 0.0;
            final lon = location.lon ?? 0.0;
            _mapController.move(LatLng(lat, lon), 4);
          },
          child: const Icon(LucideIcons.focus),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error building Earth Events Map: $e');
      debugPrint('Stack trace: $stackTrace');
      return Scaffold(
        appBar: AppBar(title: const Text('Earth Events Map')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.triangleAlert, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading map', style: context.textTheme.titleMedium),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  e.toString(),
                  style: context.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
