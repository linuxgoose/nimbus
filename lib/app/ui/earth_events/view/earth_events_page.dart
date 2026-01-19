import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/earth_events_service.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/ui/earth_events/view/earth_events_map.dart';
import 'package:intl/intl.dart';

class EarthEventsPage extends StatefulWidget {
  const EarthEventsPage({super.key});

  @override
  State<EarthEventsPage> createState() => _EarthEventsPageState();
}

class _EarthEventsPageState extends State<EarthEventsPage> {
  final weatherController = Get.find<WeatherController>();

  List<Map<String, dynamic>>? earthquakes;
  List<Map<String, dynamic>>? nwsAlerts;
  List<Map<String, dynamic>>? wildfires;
  List<Map<String, dynamic>>? gdacsAlerts;
  List<Map<String, dynamic>>? eonetEvents;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadEarthEvents();
  }

  Future<void> _loadEarthEvents({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final lat = weatherController.location.lat;
      final lon = weatherController.location.lon;

      if (lat == null || lon == null) {
        setState(() {
          error = 'Location unavailable';
          isLoading = false;
        });
        return;
      }

      // Fetch all data concurrently
      final results = await Future.wait([
        EarthEventsService.getRecentEarthquakes(),
        EarthEventsService.getNWSAlerts(latitude: lat, longitude: lon),
        EarthEventsService.getActiveFires(
          latitude: lat,
          longitude: lon,
          radiusDegrees: 10.0,
        ),
        EarthEventsService.getGDACSAlerts(),
        EarthEventsService.getNaturalEvents(days: 30),
      ]);

      setState(() {
        earthquakes = results[0];
        nwsAlerts = results[1];
        wildfires = results[2];
        gdacsAlerts = results[3];
        eonetEvents = results[4];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load earth events data';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earth Events'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.map),
            onPressed: () {
              print('Opening map with data:');
              print('Earthquakes: ${earthquakes?.length ?? 0}');
              print('Wildfires: ${wildfires?.length ?? 0}');
              print('GDACS: ${gdacsAlerts?.length ?? 0}');
              print('EONET: ${eonetEvents?.length ?? 0}');
              Get.to(
                () => EarthEventsMapPage(
                  earthquakes: earthquakes,
                  wildfires: wildfires,
                  gdacsAlerts: gdacsAlerts,
                  eonetEvents: eonetEvents,
                ),
                transition: Transition.downToUp,
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => _loadEarthEvents(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadEarthEvents(forceRefresh: true),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _buildErrorView()
            : _buildContent(),
      ),
    );
  }

  Widget _buildErrorView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.circleAlert, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(error!, style: context.textTheme.titleMedium),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadEarthEvents,
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (gdacsAlerts != null && gdacsAlerts!.isNotEmpty) ...[
          _buildGDACSAlertsCard(),
          const SizedBox(height: 16),
        ],
        if (earthquakes != null && earthquakes!.isNotEmpty) ...[
          _buildEarthquakesCard(),
          const SizedBox(height: 16),
        ],
        if (wildfires != null && wildfires!.isNotEmpty) ...[
          _buildWildfiresCard(),
          const SizedBox(height: 16),
        ],
        if (eonetEvents != null && eonetEvents!.isNotEmpty) ...[
          _buildEONETEventsCard(),
          const SizedBox(height: 16),
        ],
        if (nwsAlerts != null && nwsAlerts!.isNotEmpty) ...[
          _buildNWSAlertsCard(),
          const SizedBox(height: 16),
        ],
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildGDACSAlertsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.globe,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Global Disaster Alerts',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'GDACS - Active disasters worldwide',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...gdacsAlerts!.take(5).map((alert) => _buildGDACSAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildGDACSAlertItem(Map<String, dynamic> alert) {
    final eventType = alert['eventtype'] ?? 'Unknown';
    final eventName = alert['eventname'] ?? 'Unknown Event';
    final alertLevel = alert['alertlevel'] ?? '';
    final country = alert['country'] ?? '';
    final colorHex = alert['color'] ?? '#666666';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final iconName = alert['icon'] ?? 'alert-triangle';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIconData(iconName), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eventName,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (country.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                country,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$eventType · $alertLevel Alert',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarthquakesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.waves,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Earthquakes',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Significant earthquakes (4.5+ magnitude) in the past week',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...earthquakes!.take(5).map((quake) => _buildEarthquakeItem(quake)),
          ],
        ),
      ),
    );
  }

  Widget _buildEarthquakeItem(Map<String, dynamic> quake) {
    final magnitude = quake['magnitude'] ?? 0.0;
    final place = quake['place'] ?? 'Unknown location';
    final time = quake['time'] as int?;
    final colorHex = quake['color'] ?? '#666666';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final severity = quake['severity'] ?? 'Unknown';
    final tsunami = quake['tsunami'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    magnitude.toStringAsFixed(1),
                    style: context.textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    severity,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tsunami)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TSUNAMI',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (time != null)
                  Text(
                    _formatTime(time),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWildfiresCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.flame,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Wildfires',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'NASA FIRMS - Active fire detections in your region',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...wildfires!.take(10).map((fire) => _buildWildfireItem(fire)),
          ],
        ),
      ),
    );
  }

  Widget _buildWildfireItem(Map<String, dynamic> fire) {
    final frp = fire['frp'] ?? 0.0;
    final confidence = fire['confidence'] ?? 'l';
    final severity = fire['severity'] ?? 'Low';
    final colorHex = fire['color'] ?? '#666666';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final brightness = fire['brightness'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(LucideIcons.flame, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fire Radiative Power: ${frp.toStringAsFixed(1)} MW',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Brightness: ${brightness.toStringAsFixed(0)}K · Confidence: ${confidence.toUpperCase()}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              severity,
              style: context.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEONETEventsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.satellite,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Natural Events',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'NASA EONET - Active natural phenomena worldwide',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...eonetEvents!.take(8).map((event) => _buildEONETEventItem(event)),
          ],
        ),
      ),
    );
  }

  Widget _buildEONETEventItem(Map<String, dynamic> event) {
    final title = event['title'] ?? 'Unknown Event';
    final category = event['category'] ?? 'Unknown';
    final colorHex = event['color'] ?? '#666666';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final iconName = event['icon'] ?? 'alert-circle';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_getIconData(iconName), color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  category,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNWSAlertsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'NWS Weather Alerts',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...nwsAlerts!.take(3).map((alert) => _buildNWSAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildNWSAlertItem(Map<String, dynamic> alert) {
    final event = alert['event'] ?? 'Weather Alert';
    final severity = alert['severity'] ?? 'Unknown';
    final areaDesc = alert['areaDesc'] ?? '';
    final colorHex = alert['color'] ?? '#666666';
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final urgency = alert['urgency'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.circleAlert, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            if (areaDesc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                areaDesc,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (urgency.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$severity · $urgency',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.info,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'About Earth Events',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'This page aggregates real-time natural disaster and Earth event data from multiple authoritative sources to keep you informed about global and local events.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Data sources: USGS Earthquakes, NASA FIRMS (Wildfires), GDACS (Global Disasters), NASA EONET (Natural Events), NWS (Weather Alerts)',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
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

  String _formatTime(int timestamp) {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('MMM d').format(dt.toLocal());
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
