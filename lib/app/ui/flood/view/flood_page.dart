import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/flood_service.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/main.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FloodPage extends StatefulWidget {
  const FloodPage({super.key});

  @override
  State<FloodPage> createState() => _FloodPageState();
}

class _FloodPageState extends State<FloodPage> {
  final weatherController = Get.find<WeatherController>();
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> floodWarnings = [];
  List<Map<String, dynamic>> monitoringStations = [];
  bool isLoading = true;
  String? error;
  bool showMap = true;

  @override
  void initState() {
    super.initState();
    _loadFloodData();
  }

  Future<void> _loadFloodData({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final lat =
          weatherController.location.lat ?? 51.5074; // Default to London
      final lon = weatherController.location.lon ?? -0.1278;

      // Get flood warnings from all UK regions
      final warnings = await FloodService.getAllUKFloodWarnings(
        lat: lat,
        lon: lon,
        radiusKm: settings.floodRadiusKm,
      );

      // Get monitoring stations from all UK regions
      final stations = await FloodService.getAllUKStations(
        lat: lat,
        lon: lon,
        radiusKm: settings.floodRadiusKm,
        limit: 50,
      );

      setState(() {
        floodWarnings = warnings;
        monitoringStations = stations;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load flood data';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UK Flood Monitoring'),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(showMap ? LucideIcons.list : LucideIcons.map),
            onPressed: () => setState(() => showMap = !showMap),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => _loadFloodData(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadFloodData(forceRefresh: true),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _buildErrorView()
            : showMap
            ? _buildMapView()
            : _buildListView(),
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
          onPressed: _loadFloodData,
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildMapView() {
    final lat = weatherController.location.lat ?? 51.5074;
    final lon = weatherController.location.lon ?? -0.1278;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(lat, lon),
        initialZoom: 9.0,
        minZoom: 6.0,
        maxZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.linuxgoose.nimbus',
        ),
        // Flood warning markers
        MarkerLayer(
          markers: floodWarnings
              .map((warning) {
                // Parse first coordinate from polygon
                final polygon = warning['polygon'] as String?;
                if (polygon == null) return null;

                final coords = polygon.split(',').first.trim().split(' ');
                if (coords.length < 2) return null;

                final wLat = double.tryParse(coords[0]);
                final wLon = double.tryParse(coords[1]);
                if (wLat == null || wLon == null) return null;

                final severityLevel = warning['severityLevel'] as int? ?? 0;
                final colorHex = FloodService.getSeverityColor(severityLevel);
                final color = Color(
                  int.parse(colorHex.replaceFirst('#', '0xFF')),
                );

                return Marker(
                  point: LatLng(wLat, wLon),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showWarningDetails(warning),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        LucideIcons.droplet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              })
              .whereType<Marker>()
              .toList(),
        ),
        // Monitoring station markers
        MarkerLayer(
          markers: monitoringStations
              .map((station) {
                final sLat = station['lat'] as double?;
                final sLon = station['long'] as double?;
                if (sLat == null || sLon == null) return null;

                return Marker(
                  point: LatLng(sLat, sLon),
                  width: 30,
                  height: 30,
                  child: GestureDetector(
                    onTap: () => _showStationDetails(station),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        LucideIcons.gauge,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                );
              })
              .whereType<Marker>()
              .toList(),
        ),
        // User location marker
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(lat, lon),
              width: 40,
              height: 40,
              child: const Icon(
                LucideIcons.mapPin,
                color: Colors.red,
                size: 40,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        if (floodWarnings.isNotEmpty) ...[
          _buildSectionHeader('Active Flood Warnings'),
          const SizedBox(height: 8),
          ...floodWarnings.map((warning) => _buildWarningCard(warning)),
          const SizedBox(height: 16),
        ],
        if (monitoringStations.isNotEmpty) ...[
          _buildSectionHeader('Monitoring Stations'),
          const SizedBox(height: 8),
          ...monitoringStations
              .take(10)
              .map((station) => _buildStationCard(station)),
        ],
        if (floodWarnings.isEmpty && monitoringStations.isEmpty)
          _buildNoDataCard(),
        const SizedBox(height: 16),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final severeCount = floodWarnings
        .where((w) => w['severityLevel'] == 1)
        .length;
    final warningCount = floodWarnings
        .where((w) => w['severityLevel'] == 2)
        .length;
    final alertCount = floodWarnings
        .where((w) => w['severityLevel'] == 3)
        .length;

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
                  'Flood Summary',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Severe Warnings', severeCount, Colors.red),
            _buildSummaryRow('Warnings', warningCount, Colors.orange),
            _buildSummaryRow('Alerts', alertCount, Colors.yellow.shade700),
            const Divider(height: 24),
            Text(
              '${monitoringStations.length} monitoring stations nearby',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
          Text(
            count.toString(),
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildWarningCard(Map<String, dynamic> warning) {
    final severityLevel = warning['severityLevel'] as int? ?? 0;
    final colorHex = FloodService.getSeverityColor(severityLevel);
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    final severity = warning['severity'] as String? ?? 'Unknown';
    final description = warning['description'] as String? ?? '';
    final county = warning['county'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showWarningDetails(warning),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(LucideIcons.droplet, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      severity,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (county.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(county, style: context.textTheme.bodyMedium),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationCard(Map<String, dynamic> station) {
    final label = station['label'] as String? ?? 'Unknown';
    final riverName = station['riverName'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showStationDetails(station),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.gauge,
                  color: context.theme.colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (riverName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        riverName,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              LucideIcons.smile,
              size: 64,
              color: context.theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Flood Warnings',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are currently no flood warnings in your area',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
                  'About Flood Monitoring',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Real-time flood monitoring data for the UK from regional agencies.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '🏴󠁧󠁢󠁥󠁮󠁧󠁿 England: Environment Agency\n🏴󠁧󠁢󠁳󠁣󠁴󠁿 Scotland: SEPA\n🏴󠁧󠁢󠁷󠁬󠁳󠁿 Wales: Natural Resources Wales\n🇮🇪 Northern Ireland: Limited data (no public API)',
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Severe Warning', 'Danger to life - act now'),
            _buildInfoRow('Warning', 'Flooding is expected - act now'),
            _buildInfoRow('Alert', 'Flooding is possible - be prepared'),
            const SizedBox(height: 12),
            Text(
              'Note: Monitoring stations show real-time river levels for England, Scotland, and Wales. Northern Ireland does not currently provide a public API for automated flood data access.',
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

  Widget _buildInfoRow(String label, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWarningDetails(Map<String, dynamic> warning) {
    final severity = warning['severity'] as String? ?? 'Unknown';
    final description = warning['description'] as String? ?? '';
    final message = warning['message'] as String? ?? '';
    final county = warning['county'] as String? ?? '';
    final timeRaised = warning['timeRaised'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  severity,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (county.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(county, style: context.textTheme.titleMedium),
                ],
                const SizedBox(height: 16),
                if (description.isNotEmpty) ...[
                  Text(description, style: context.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                ],
                if (message.isNotEmpty) ...[
                  Text(
                    'Details',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, style: context.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                ],
                if (timeRaised != null) ...[
                  Text(
                    'Raised: ${_formatTime(timeRaised)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStationDetails(Map<String, dynamic> station) {
    final label = station['label'] as String? ?? 'Unknown';
    final riverName = station['riverName'] as String?;
    final stationRef = station['stationReference'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (riverName != null) ...[
              const SizedBox(height: 8),
              Text(riverName, style: context.textTheme.titleMedium),
            ],
            const SizedBox(height: 16),
            Text(
              'Station Reference: $stationRef',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This monitoring station provides real-time river level data.',
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM d, yyyy HH:mm').format(dt.toLocal());
    } catch (e) {
      return timestamp;
    }
  }
}
