import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/hiking_service.dart';
import 'package:nimbus/main.dart';

class HikingPage extends StatefulWidget {
  final double lat;
  final double lon;
  final String locationName;

  const HikingPage({
    super.key,
    required this.lat,
    required this.lon,
    required this.locationName,
  });

  @override
  State<HikingPage> createState() => _HikingPageState();
}

class _HikingPageState extends State<HikingPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _hikingData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHikingData();
  }

  // Unit conversion helpers
  String _formatTemperature(double temp) {
    if (settings.degrees == 'fahrenheit') {
      return '${((temp * 9 / 5) + 32).toStringAsFixed(1)}°F';
    }
    return '${temp.toStringAsFixed(1)}°C';
  }

  String _formatWindSpeed(double speedKmh) {
    if (settings.measurements == 'imperial') {
      if (settings.wind == 'knots') {
        return '${(speedKmh * 0.539957).toStringAsFixed(1)} ${'knots'.tr}';
      }
      return '${(speedKmh * 0.621371).toStringAsFixed(1)} ${'mph'.tr}';
    }
    if (settings.wind == 'm/s') {
      return '${(speedKmh / 3.6).toStringAsFixed(1)} ${'m/s'.tr}';
    }
    return '${speedKmh.toStringAsFixed(1)} ${'kph'.tr}';
  }

  String _formatVisibility(double visibilityKm) {
    if (settings.measurements == 'imperial') {
      return '${(visibilityKm * 0.621371).toStringAsFixed(1)} ${'mi'.tr}';
    }
    return '${visibilityKm.toStringAsFixed(1)} ${'km'.tr}';
  }

  String _formatDistance(double distanceMeters) {
    if (settings.measurements == 'imperial') {
      return '${(distanceMeters * 3.28084).toStringAsFixed(0)} ft';
    }
    return '${distanceMeters.toStringAsFixed(0)} m';
  }

  String _formatSnowDepth(double snowDepthCm) {
    if (settings.measurements == 'imperial') {
      return '${(snowDepthCm * 0.393701).toStringAsFixed(1)} ${'inch'.tr}';
    }
    return '${snowDepthCm.toStringAsFixed(0)} cm';
  }

  Future<void> _loadHikingData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await HikingService.getHikingData(
        lat: widget.lat,
        lon: widget.lon,
      );

      if (mounted) {
        setState(() {
          _hikingData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load hiking data';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hiking Conditions'),
            Text(
              widget.locationName,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.triangleAlert,
                    size: 48,
                    color: context.theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadHikingData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHikingData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentConditions(),
                    const SizedBox(height: 16),
                    _buildUVIndexChart(),
                    const SizedBox(height: 16),
                    _buildVisibilityChart(),
                    const SizedBox(height: 16),
                    _buildWindConditionsCard(),
                    const SizedBox(height: 16),
                    _buildSnowDepthCard(),
                    const SizedBox(height: 16),
                    _buildWeeklyForecast(),
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentConditions() {
    if (_hikingData == null) return const SizedBox.shrink();

    final hourly = _hikingData!['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentHourIndex = now.hour;

    final temp = hourly['temperature_2m'][currentHourIndex] is num
        ? (hourly['temperature_2m'][currentHourIndex] as num).toDouble()
        : null;
    final feelsLike = hourly['apparent_temperature'][currentHourIndex] is num
        ? (hourly['apparent_temperature'][currentHourIndex] as num).toDouble()
        : null;
    final uvIndex = hourly['uv_index'][currentHourIndex] is num
        ? (hourly['uv_index'][currentHourIndex] as num).toDouble()
        : null;
    final visibility = hourly['visibility'][currentHourIndex] is num
        ? (hourly['visibility'][currentHourIndex] as num).toDouble() / 1000
        : null;
    final windSpeed = hourly['wind_speed_10m'][currentHourIndex] is num
        ? (hourly['wind_speed_10m'][currentHourIndex] as num).toDouble()
        : null;
    final precipitation = hourly['precipitation'][currentHourIndex] is num
        ? (hourly['precipitation'][currentHourIndex] as num).toDouble()
        : null;
    final snowDepth = hourly['snow_depth'][currentHourIndex] is num
        ? (hourly['snow_depth'][currentHourIndex] as num).toDouble()
        : null;

    final conditions = HikingService.getHikingConditions(
      temp: temp ?? 15,
      precipitation: precipitation,
      windSpeed: windSpeed,
      visibility: visibility,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.mountain, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Current Trail Conditions',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              conditions,
              style: context.textTheme.titleMedium?.copyWith(
                color: _getConditionsColor(conditions),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _buildConditionChip(
                  'Temperature',
                  temp != null ? _formatTemperature(temp) : 'N/A',
                  LucideIcons.thermometer,
                ),
                _buildConditionChip(
                  'Feels Like',
                  feelsLike != null ? _formatTemperature(feelsLike) : 'N/A',
                  LucideIcons.thermometer,
                ),
                _buildConditionChip(
                  'UV Index',
                  uvIndex != null ? uvIndex.toStringAsFixed(1) : 'N/A',
                  LucideIcons.sun,
                ),
                _buildConditionChip(
                  'Visibility',
                  visibility != null ? _formatVisibility(visibility) : 'N/A',
                  LucideIcons.eye,
                ),
                _buildConditionChip(
                  'Wind',
                  windSpeed != null ? _formatWindSpeed(windSpeed) : 'N/A',
                  LucideIcons.wind,
                ),
                if (snowDepth != null && snowDepth > 0)
                  _buildConditionChip(
                    'Snow Depth',
                    _formatSnowDepth(snowDepth),
                    LucideIcons.snowflake,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionsColor(String conditions) {
    if (conditions.contains('Excellent')) return Colors.green;
    if (conditions.contains('Good')) return Colors.lightGreen;
    if (conditions.contains('Fair')) return Colors.orange;
    if (conditions.contains('Poor')) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildConditionChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUVIndexChart() {
    if (_hikingData == null) return const SizedBox.shrink();

    final hourly = _hikingData!['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const SizedBox.shrink();

    final times = hourly['time'] as List;
    final uvIndexData = hourly['uv_index'] as List;
    final isDayData = hourly['is_day'] as List;

    // Get next 48 hours
    final dataPoints = <FlSpot>[];

    for (int i = 0; i < 48 && i < times.length; i++) {
      final uvValue = uvIndexData[i] is num
          ? (uvIndexData[i] as num).toDouble()
          : null;
      final isDay = isDayData[i] == 1;

      if (uvValue != null && isDay) {
        dataPoints.add(FlSpot(i.toDouble(), uvValue));
      }
    }

    if (dataPoints.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No UV data available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.sun, size: 20),
                const SizedBox(width: 8),
                Text(
                  'UV Index - Next 48 Hours',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: context.theme.colorScheme.outline.withOpacity(
                          0.2,
                        ),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
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
                          final index = value.toInt();
                          if (index >= 0 && index < times.length) {
                            final time = DateTime.parse(times[index]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('HH:mm').format(time),
                                style: context.textTheme.bodySmall,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 47,
                  minY: 0,
                  maxY:
                      dataPoints
                          .map((e) => e.y)
                          .reduce((a, b) => a > b ? a : b) +
                      1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: dataPoints,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.3),
                            Colors.orange.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final time = DateTime.parse(times[index]);
                          return LineTooltipItem(
                            '${DateFormat('HH:mm').format(time)}\nUV: ${spot.y.toStringAsFixed(1)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildUVLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildUVLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLegendItem('Low (0-2)', Colors.green),
        _buildLegendItem('Moderate (3-5)', Colors.yellow),
        _buildLegendItem('High (6-7)', Colors.orange),
        _buildLegendItem('Very High (8-10)', Colors.red),
        _buildLegendItem('Extreme (11+)', Colors.purple),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: context.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildVisibilityChart() {
    if (_hikingData == null) return const SizedBox.shrink();

    final hourly = _hikingData!['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const SizedBox.shrink();

    final times = hourly['time'] as List;
    final visibilityData = hourly['visibility'] as List;

    // Get next 48 hours
    final dataPoints = <FlSpot>[];

    for (int i = 0; i < 48 && i < times.length; i++) {
      final visibility = visibilityData[i] is num
          ? (visibilityData[i] as num).toDouble() / 1000
          : null;

      if (visibility != null) {
        dataPoints.add(FlSpot(i.toDouble(), visibility));
      }
    }

    if (dataPoints.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.eye, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Visibility - Next 48 Hours',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: context.theme.colorScheme.outline.withOpacity(
                          0.2,
                        ),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final unit = settings.measurements == 'imperial'
                              ? 'mi'
                              : 'km';
                          final displayValue =
                              settings.measurements == 'imperial'
                              ? (value * 0.621371).toInt()
                              : value.toInt();
                          return Text(
                            '$displayValue $unit',
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
                          final index = value.toInt();
                          if (index >= 0 && index < times.length) {
                            final time = DateTime.parse(times[index]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat('HH:mm').format(time),
                                style: context.textTheme.bodySmall,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 47,
                  minY: 0,
                  maxY:
                      dataPoints
                          .map((e) => e.y)
                          .reduce((a, b) => a > b ? a : b) +
                      5,
                  lineBarsData: [
                    LineChartBarData(
                      spots: dataPoints,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.blue.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final time = DateTime.parse(times[index]);
                          final visKm = spot.y;
                          final formattedVis =
                              settings.measurements == 'imperial'
                              ? '${(visKm * 0.621371).toStringAsFixed(1)} mi'
                              : '${visKm.toStringAsFixed(1)} km';
                          return LineTooltipItem(
                            '${DateFormat('HH:mm').format(time)}\n$formattedVis',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindConditionsCard() {
    if (_hikingData == null) return const SizedBox.shrink();

    final hourly = _hikingData!['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentHourIndex = now.hour;

    final windSpeed = hourly['wind_speed_10m'][currentHourIndex] is num
        ? (hourly['wind_speed_10m'][currentHourIndex] as num).toDouble()
        : null;
    final windGusts = hourly['wind_gusts_10m'][currentHourIndex] is num
        ? (hourly['wind_gusts_10m'][currentHourIndex] as num).toDouble()
        : null;
    final windDirection = hourly['wind_direction_10m'][currentHourIndex] is num
        ? (hourly['wind_direction_10m'][currentHourIndex] as num).toDouble()
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.wind, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Wind Conditions',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (windSpeed != null) ...[
              Text(
                HikingService.getWindCategory(windSpeed),
                style: context.textTheme.titleMedium?.copyWith(
                  color: context.theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _buildWindMetric(
                    'Speed',
                    windSpeed != null ? _formatWindSpeed(windSpeed) : 'N/A',
                    LucideIcons.gauge,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWindMetric(
                    'Gusts',
                    windGusts != null ? _formatWindSpeed(windGusts) : 'N/A',
                    LucideIcons.wind,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWindMetric(
                    'Direction',
                    windDirection != null
                        ? _getWindDirection(windDirection)
                        : 'N/A',
                    LucideIcons.compass,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: context.theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getWindDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  Widget _buildSnowDepthCard() {
    if (_hikingData == null) return const SizedBox.shrink();

    final hourly = _hikingData!['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentHourIndex = now.hour;

    final snowDepth = hourly['snow_depth'][currentHourIndex] is num
        ? (hourly['snow_depth'][currentHourIndex] as num).toDouble()
        : null;
    final freezingLevel =
        hourly['freezing_level_height'][currentHourIndex] is num
        ? (hourly['freezing_level_height'][currentHourIndex] as num).toDouble()
        : null;

    if (snowDepth == null || snowDepth < 0.1) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.snowflake, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Snow Conditions',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              HikingService.getSnowDepthCategory(snowDepth),
              style: context.textTheme.titleMedium?.copyWith(
                color: Colors.lightBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSnowMetric(
                    'Snow Depth',
                    _formatSnowDepth(snowDepth),
                    LucideIcons.snowflake,
                  ),
                ),
                if (freezingLevel != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSnowMetric(
                      'Freezing Level',
                      _formatDistance(freezingLevel),
                      LucideIcons.thermometer,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnowMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.lightBlue),
          const SizedBox(height: 8),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyForecast() {
    if (_hikingData == null) return const SizedBox.shrink();

    final daily = _hikingData!['daily'] as Map<String, dynamic>?;
    if (daily == null) return const SizedBox.shrink();

    final times = daily['time'] as List;
    final maxTemps = daily['temperature_2m_max'] as List;
    final minTemps = daily['temperature_2m_min'] as List;
    final uvIndexMax = daily['uv_index_max'] as List;
    final precipSum = daily['precipitation_sum'] as List;
    final windMax = daily['wind_speed_10m_max'] as List;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 20),
                const SizedBox(width: 8),
                Text(
                  '7-Day Hiking Forecast',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(7, (index) {
              final date = DateTime.parse(times[index]);
              final maxTemp = maxTemps[index] is num
                  ? (maxTemps[index] as num).toDouble()
                  : null;
              final minTemp = minTemps[index] is num
                  ? (minTemps[index] as num).toDouble()
                  : null;
              final uv = uvIndexMax[index] is num
                  ? (uvIndexMax[index] as num).toDouble()
                  : null;
              final precip = precipSum[index] is num
                  ? (precipSum[index] as num).toDouble()
                  : null;
              final wind = windMax[index] is num
                  ? (windMax[index] as num).toDouble()
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        DateFormat('EEE, MMM d').format(date),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (maxTemp != null && minTemp != null)
                            Text(
                              settings.degrees == 'fahrenheit'
                                  ? '${((maxTemp * 9 / 5) + 32).toStringAsFixed(0)}°/${((minTemp * 9 / 5) + 32).toStringAsFixed(0)}°'
                                  : '${maxTemp.toStringAsFixed(0)}°/${minTemp.toStringAsFixed(0)}°',
                              style: context.textTheme.bodyMedium,
                            ),
                          if (uv != null)
                            Row(
                              children: [
                                const Icon(LucideIcons.sun, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  uv.toStringAsFixed(0),
                                  style: context.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          if (precip != null && precip > 0)
                            Row(
                              children: [
                                const Icon(LucideIcons.droplet, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  settings.measurements == 'imperial'
                                      ? '${(precip * 0.0393701).toStringAsFixed(2)}"'
                                      : '${precip.toStringAsFixed(1)}mm',
                                  style: context.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          if (wind != null)
                            Row(
                              children: [
                                const Icon(LucideIcons.wind, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  settings.measurements == 'imperial'
                                      ? '${(wind * 0.621371).toStringAsFixed(0)}mph'
                                      : settings.wind == 'm/s'
                                      ? '${(wind / 3.6).toStringAsFixed(0)}m/s'
                                      : '${wind.toStringAsFixed(0)}km/h',
                                  style: context.textTheme.bodySmall,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'About Hiking Data',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              settings.weatherDataSource == 'nimbusmeteo'
                  ? 'This page provides comprehensive hiking weather data including UV index, visibility, wind conditions, and snow depth. Data is updated hourly from Nimbus Meteo. Plan your outdoor adventures safely with detailed forecasts and safety recommendations.'
                  : 'This page provides comprehensive hiking weather data including UV index, visibility, wind conditions, and snow depth. Data is updated hourly from Open-Meteo. Plan your outdoor adventures safely with detailed forecasts and safety recommendations.',
              style: context.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
