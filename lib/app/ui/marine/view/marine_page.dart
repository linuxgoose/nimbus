import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/marine_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class MarinePage extends StatefulWidget {
  final double lat;
  final double lon;
  final String locationName;

  const MarinePage({
    super.key,
    required this.lat,
    required this.lon,
    required this.locationName,
  });

  @override
  State<MarinePage> createState() => _MarinePageState();
}

class _MarinePageState extends State<MarinePage> {
  Map<String, dynamic>? marineData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await MarineService.getMarineData(
        lat: widget.lat,
        lon: widget.lon,
      );

      setState(() {
        marineData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load marine data';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marine Conditions'),
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : marineData == null
          ? const Center(child: Text('No data available'))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final hourly = marineData!['hourly'] as Map<String, dynamic>?;
    final daily = marineData!['daily'] as Map<String, dynamic>?;

    if (hourly == null || daily == null) {
      return const Center(child: Text('Invalid data format'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocationHeader(),
          const SizedBox(height: 16),
          _buildCurrentConditions(hourly),
          const SizedBox(height: 16),
          _buildWaveHeightChart(hourly),
          const SizedBox(height: 16),
          _buildSwellChart(hourly),
          const SizedBox(height: 16),
          _buildOceanCurrentCard(hourly),
          const SizedBox(height: 16),
          _buildWavePeriodCard(hourly),
          const SizedBox(height: 16),
          _buildWeeklyForecast(daily),
          const SizedBox(height: 16),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildLocationHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(LucideIcons.mapPin, color: context.theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.locationName,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.lat.toStringAsFixed(2)}°, ${widget.lon.toStringAsFixed(2)}°',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentConditions(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    if (times == null || times.isEmpty) return const SizedBox();

    final waveHeight = (hourly['wave_height'] as List<dynamic>?)?[0] is num
        ? ((hourly['wave_height'] as List<dynamic>?)?[0] as num).toDouble()
        : null;
    final swellHeight =
        (hourly['swell_wave_height'] as List<dynamic>?)?[0] is num
        ? ((hourly['swell_wave_height'] as List<dynamic>?)?[0] as num)
              .toDouble()
        : null;
    final windWaveHeight =
        (hourly['wind_wave_height'] as List<dynamic>?)?[0] is num
        ? ((hourly['wind_wave_height'] as List<dynamic>?)?[0] as num).toDouble()
        : null;
    final currentSpeed =
        (hourly['ocean_current_velocity'] as List<dynamic>?)?[0] is num
        ? ((hourly['ocean_current_velocity'] as List<dynamic>?)?[0] as num)
              .toDouble()
        : null;

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
                  'Current Conditions',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildConditionRow(
              'Total Wave Height',
              waveHeight != null ? '${waveHeight.toStringAsFixed(2)} m' : 'N/A',
              waveHeight != null
                  ? MarineService.getWaveCategory(waveHeight)
                  : '',
            ),
            const Divider(height: 24),
            _buildConditionRow(
              'Wind Wave Height',
              windWaveHeight != null
                  ? '${windWaveHeight.toStringAsFixed(2)} m'
                  : 'N/A',
              'Locally generated waves',
            ),
            const Divider(height: 24),
            _buildConditionRow(
              'Swell Height',
              swellHeight != null
                  ? '${swellHeight.toStringAsFixed(2)} m'
                  : 'N/A',
              swellHeight != null
                  ? MarineService.getSwellCategory(swellHeight)
                  : '',
            ),
            const Divider(height: 24),
            _buildConditionRow(
              'Ocean Current',
              currentSpeed != null
                  ? '${currentSpeed.toStringAsFixed(2)} m/s'
                  : 'N/A',
              currentSpeed != null
                  ? MarineService.getCurrentCategory(currentSpeed)
                  : '',
            ),
            if (waveHeight != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        MarineService.getSafetyRecommendation(
                          waveHeight,
                          windWaveHeight,
                        ),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConditionRow(String label, String value, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWaveHeightChart(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    final waveHeight = hourly['wave_height'] as List<dynamic>?;
    final windWaveHeight = hourly['wind_wave_height'] as List<dynamic>?;

    if (times == null || waveHeight == null) return const SizedBox();

    // Take first 48 hours
    final limit = times.length > 48 ? 48 : times.length;

    final waveSpots = <FlSpot>[];
    final windWaveSpots = <FlSpot>[];

    for (var i = 0; i < limit; i++) {
      final wave = waveHeight[i] is num
          ? (waveHeight[i] as num).toDouble()
          : null;
      final windWave = windWaveHeight?[i] is num
          ? (windWaveHeight![i] as num).toDouble()
          : null;

      if (wave != null) {
        waveSpots.add(FlSpot(i.toDouble(), wave));
      }
      if (windWave != null) {
        windWaveSpots.add(FlSpot(i.toDouble(), windWave));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wave Height (48h Forecast)',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total wave and wind wave heights',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.5,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}m',
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 6,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= times.length) {
                            return const SizedBox();
                          }
                          final time = DateTime.parse(
                            times[value.toInt()] as String,
                          );
                          return Text(
                            DateFormat('HH:00').format(time),
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: waveSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                    if (windWaveSpots.isNotEmpty)
                      LineChartBarData(
                        spots: windWaveSpots,
                        isCurved: true,
                        color: Colors.cyan,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        dashArray: [5, 5],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Total Wave', Colors.blue),
                const SizedBox(width: 24),
                _buildLegendItem('Wind Wave', Colors.cyan),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwellChart(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    final swellHeight = hourly['swell_wave_height'] as List<dynamic>?;

    if (times == null || swellHeight == null) return const SizedBox();

    final limit = times.length > 48 ? 48 : times.length;
    final swellSpots = <FlSpot>[];

    for (var i = 0; i < limit; i++) {
      final swell = swellHeight[i] is num
          ? (swellHeight[i] as num).toDouble()
          : null;
      if (swell != null) {
        swellSpots.add(FlSpot(i.toDouble(), swell));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Swell Height (48h Forecast)',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Long-period waves from distant storms',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.5,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}m',
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 6,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= times.length) {
                            return const SizedBox();
                          }
                          final time = DateTime.parse(
                            times[value.toInt()] as String,
                          );
                          return Text(
                            DateFormat('HH:00').format(time),
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: swellSpots,
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.teal.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOceanCurrentCard(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    final currentVelocity = hourly['ocean_current_velocity'] as List<dynamic>?;
    final currentDirection =
        hourly['ocean_current_direction'] as List<dynamic>?;

    if (times == null || currentVelocity == null) return const SizedBox();

    final velocity = currentVelocity[0] is num
        ? (currentVelocity[0] as num).toDouble()
        : null;
    final direction = currentDirection?[0] is num
        ? (currentDirection![0] as num).toDouble()
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.navigation,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ocean Current',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Speed',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      velocity != null
                          ? '${velocity.toStringAsFixed(2)} m/s'
                          : 'N/A',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.theme.colorScheme.primary,
                      ),
                    ),
                    if (velocity != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        MarineService.getCurrentCategory(velocity),
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Direction',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      direction != null
                          ? '${direction.toStringAsFixed(0)}°'
                          : 'N/A',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.theme.colorScheme.primary,
                      ),
                    ),
                    if (direction != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getCardinalDirection(direction),
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWavePeriodCard(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    final wavePeriod = hourly['wave_period'] as List<dynamic>?;

    if (times == null || wavePeriod == null) return const SizedBox();

    final period = wavePeriod[0] is num
        ? (wavePeriod[0] as num).toDouble()
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.timer,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Wave Period',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    period != null ? '${period.toStringAsFixed(1)} s' : 'N/A',
                    style: context.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time between wave crests',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (period != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        MarineService.getWavePeriodDescription(period),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyForecast(Map<String, dynamic> daily) {
    final times = daily['time'] as List<dynamic>?;
    final waveMax = daily['wave_height_max'] as List<dynamic>?;
    final waveDirection = daily['wave_direction_dominant'] as List<dynamic>?;

    if (times == null || waveMax == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '7-Day Forecast',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(times.length > 7 ? 7 : times.length, (index) {
              final date = DateTime.parse(times[index] as String);
              final maxWave = waveMax[index] is num
                  ? (waveMax[index] as num).toDouble()
                  : null;
              final direction = waveDirection?[index] is num
                  ? (waveDirection![index] as num).toDouble()
                  : null;

              return Column(
                children: [
                  if (index > 0) const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEE, MMM d').format(date),
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (direction != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Direction: ${_getCardinalDirection(direction)}',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context
                                      .theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              maxWave != null
                                  ? '${maxWave.toStringAsFixed(2)} m'
                                  : 'N/A',
                              style: context.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.theme.colorScheme.primary,
                              ),
                            ),
                            if (maxWave != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                MarineService.getWaveCategory(maxWave),
                                style: context.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: context.theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.info,
                  color: context.theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'About Marine Data',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Marine weather data from Open-Meteo provides essential information for maritime activities, surfing, fishing, and coastal planning.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Wave Height: Total height includes both wind waves (locally generated) and swell (distant storms). '
              'Wave Period: Longer periods indicate smoother, more powerful waves. '
              'Ocean Currents: Surface current velocity and direction affect navigation and safety.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onPrimaryContainer.withOpacity(
                  0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.textTheme.bodySmall),
      ],
    );
  }

  String _getCardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
