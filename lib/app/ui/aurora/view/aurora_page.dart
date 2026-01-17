import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/aurora_service.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:intl/intl.dart';

class AuroraPage extends StatefulWidget {
  const AuroraPage({super.key});

  @override
  State<AuroraPage> createState() => _AuroraPageState();
}

class _AuroraPageState extends State<AuroraPage> {
  final weatherController = Get.find<WeatherController>();

  Map<String, dynamic>? noaaData;
  Map<String, dynamic>? ukData;
  List<Map<String, dynamic>>? forecast;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAuroraData();
  }

  Future<void> _loadAuroraData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        AuroraService.getNoaaAuroraData(),
        AuroraService.getAuroraWatchUK(),
        AuroraService.getThreeDayForecast(),
      ]);

      setState(() {
        noaaData = results[0] as Map<String, dynamic>?;
        ukData = results[1] as Map<String, dynamic>?;
        forecast = results[2] as List<Map<String, dynamic>>?;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load aurora data';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aurora Watch'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadAuroraData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAuroraData,
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
        Icon(LucideIcons.circleAlert, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(error!, style: context.textTheme.titleMedium),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadAuroraData,
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
        _buildCurrentActivityCard(),
        const SizedBox(height: 16),
        _buildVisibilityCard(),
        const SizedBox(height: 16),
        if (ukData != null) ...[
          _buildUKAlertCard(),
          const SizedBox(height: 16),
        ],
        _buildForecastCard(),
        const SizedBox(height: 16),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildCurrentActivityCard() {
    final kp = noaaData?['kp_index'] ?? 0.0;
    final activity = AuroraService.getActivityLevel(kp);
    final colorHex = AuroraService.getKpColor(kp);
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Activity',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(LucideIcons.activity, color: color, size: 32),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color, width: 3),
              ),
              child: Center(
                child: Text(
                  kp.toStringAsFixed(1),
                  style: context.textTheme.displayLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              activity,
              style: context.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kp Index',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (noaaData?['timestamp'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatTime(noaaData!['timestamp'])}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityCard() {
    final latitude = weatherController.location.lat ?? 0.0;
    final kp = noaaData?['kp_index'] ?? 0.0;
    final visibility = AuroraService.getVisibilityForLocation(kp, latitude);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.mapPin,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Visibility at Your Location',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latitude: ${latitude.toStringAsFixed(2)}°',
                      style: context.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Visibility: $visibility',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _getVisibilityIcon(visibility),
                  size: 48,
                  color: _getVisibilityColor(visibility),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getVisibilityDescription(visibility),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUKAlertCard() {
    final status = ukData?['status'] ?? 'green';
    final colorHex = AuroraService.getUKAlertColor(status);
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.bell,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AuroraWatch UK',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.triangleAlert, color: color, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.toUpperCase(),
                          style: context.textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getUKStatusDescription(status),
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (ukData?['updated'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Updated: ${_formatTime(ukData!['updated'])}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard() {
    if (forecast == null || forecast!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '3-Day Forecast',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...forecast!.take(24).map((entry) => _buildForecastItem(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastItem(Map<String, dynamic> entry) {
    final kp = entry['kp_predicted'] ?? 0.0;
    final timestamp = entry['timestamp'];
    final colorHex = AuroraService.getKpColor(kp);
    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              _formatForecastTime(timestamp),
              style: context.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: kp / 9,
              backgroundColor:
                  context.theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 20,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            alignment: Alignment.centerRight,
            child: Text(
              kp.toStringAsFixed(1),
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
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
                  'About Aurora',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'The Kp-index describes the geomagnetic activity level. Higher values indicate stronger aurora activity and visibility at lower latitudes.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Kp 0-2', 'Quiet - Visible only near poles'),
            _buildInfoRow('Kp 3-4', 'Unsettled/Active - Northern regions'),
            _buildInfoRow('Kp 5-6', 'Minor/Moderate Storm - Mid latitudes'),
            _buildInfoRow('Kp 7-9', 'Strong/Extreme Storm - Visible widely'),
            const SizedBox(height: 16),
            Text(
              'Data sources: NOAA Space Weather Prediction Center, AuroraWatch UK',
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
            width: 80,
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

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM d, HH:mm').format(dt.toLocal());
    } catch (e) {
      return timestamp;
    }
  }

  String _formatForecastTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM d HH:mm').format(dt.toLocal());
    } catch (e) {
      return timestamp;
    }
  }

  IconData _getVisibilityIcon(String visibility) {
    switch (visibility) {
      case 'Very High':
        return LucideIcons.eye;
      case 'High':
        return LucideIcons.eye;
      case 'Moderate':
        return LucideIcons.cloudMoon;
      case 'Low':
        return LucideIcons.cloudOff;
      case 'Very Low':
      default:
        return LucideIcons.eyeOff;
    }
  }

  Color _getVisibilityColor(String visibility) {
    switch (visibility) {
      case 'Very High':
        return Colors.green;
      case 'High':
        return Colors.lightGreen;
      case 'Moderate':
        return Colors.orange;
      case 'Low':
        return Colors.deepOrange;
      case 'Very Low':
      default:
        return Colors.grey;
    }
  }

  String _getVisibilityDescription(String visibility) {
    switch (visibility) {
      case 'Very High':
        return 'Excellent chance of seeing aurora. Look for clear, dark skies away from light pollution.';
      case 'High':
        return 'Good chance of aurora visibility. Find a dark location with clear northern skies.';
      case 'Moderate':
        return 'Possible aurora visibility in optimal conditions. Best viewed from higher latitudes.';
      case 'Low':
        return 'Aurora unlikely to be visible at your latitude unless activity increases significantly.';
      case 'Very Low':
      default:
        return 'Aurora very unlikely to be visible at your location with current conditions.';
    }
  }

  String _getUKStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'red':
        return 'Aurora likely to be visible across the UK';
      case 'amber':
        return 'Aurora possible from northern UK';
      case 'yellow':
        return 'Aurora may be visible from Scotland';
      case 'green':
      default:
        return 'No significant aurora activity expected';
    }
  }
}
