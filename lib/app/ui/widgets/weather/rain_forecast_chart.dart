import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nimbus/app/services/rain_forecast_service.dart';

/// Widget displaying a 6-hour predictive rain chart using Open-Meteo's
/// high-resolution minutely/15-minute precipitation data
class RainForecastChart extends StatefulWidget {
  const RainForecastChart({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<RainForecastChart> createState() => _RainForecastChartState();
}

class _RainForecastChartState extends State<RainForecastChart> {
  List<DateTime> _times = [];
  List<double> _precipitation = [];
  bool _isLoading = true;
  String _resolution = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRainData();
  }

  Future<void> _loadRainData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await RainForecastService.getMinutelyPrecipitation(
        lat: widget.latitude,
        lon: widget.longitude,
      );

      if (data != null && mounted) {
        final times = data['time'] as List<dynamic>;
        final precip = data['precipitation'] as List<dynamic>;

        setState(() {
          _times = times.map((t) => DateTime.parse(t as String)).toList();
          _precipitation = precip
              .map((p) => (p as num?)?.toDouble() ?? 0.0)
              .toList();
          _resolution = data['resolution'] as String? ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _error = 'No precipitation data available';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load rain forecast';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.water_drop,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '6-Hour Rain Forecast',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (!_isLoading && _error == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _resolution == '15min' ? '15-min data' : 'Hourly data',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadRainData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_times.isEmpty || _precipitation.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No precipitation expected',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return SizedBox(height: 180, child: _buildChart(context));
  }

  Widget _buildChart(BuildContext context) {
    final maxPrecip = _precipitation.reduce((a, b) => a > b ? a : b);
    final hasRain = maxPrecip > 0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: hasRain ? (maxPrecip / 4) : 0.5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: hasRain ? (maxPrecip / 4) : 0.5,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)} mm',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _times.length) {
                  return const SizedBox();
                }

                // Only show labels at start, middle, and end for 15min data
                // Or every other hour for hourly data
                bool shouldShow = false;
                if (_resolution == '15min') {
                  // Show first, middle, and last time labels
                  shouldShow =
                      index == 0 ||
                      index == (_times.length / 2).round() ||
                      index == _times.length - 1;
                } else {
                  // For hourly, show every 2 hours
                  shouldShow = index % 2 == 0;
                }

                if (!shouldShow) {
                  return const SizedBox();
                }

                final time = _times[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat.Hm().format(time),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            left: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
        ),
        minX: 0,
        maxX: (_times.length - 1).toDouble(),
        minY: 0,
        maxY: hasRain ? maxPrecip * 1.2 : 2,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              _precipitation.length,
              (index) => FlSpot(index.toDouble(), _precipitation[index]),
            ),
            isCurved: true,
            color: const Color(0xFF0066CC),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: _resolution == 'hourly',
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF0066CC),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0066CC).withOpacity(0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final time = _times[spot.x.toInt()];
                final precip = spot.y;
                return LineTooltipItem(
                  '${DateFormat.Hm().format(time)}\n${precip.toStringAsFixed(2)} mm',
                  Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
