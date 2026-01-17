import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/agriculture_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AgriculturePage extends StatefulWidget {
  final double lat;
  final double lon;
  final String locationName;

  const AgriculturePage({
    super.key,
    required this.lat,
    required this.lon,
    required this.locationName,
  });

  @override
  State<AgriculturePage> createState() => _AgriculturePageState();
}

class _AgriculturePageState extends State<AgriculturePage> {
  Map<String, dynamic>? agricultureData;
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
      final data = await AgricultureService.getAgricultureData(
        lat: widget.lat,
        lon: widget.lon,
      );

      setState(() {
        agricultureData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load agriculture data';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agriculture - ${widget.locationName}'),
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _buildErrorView()
            : _buildContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 48,
            color: context.theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(error ?? 'Unknown error'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (agricultureData == null) return const SizedBox();

    final hourly = agricultureData!['hourly'] as Map<String, dynamic>?;
    final daily = agricultureData!['daily'] as Map<String, dynamic>?;

    if (hourly == null || daily == null) {
      return const Center(child: Text('No data available'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCurrentConditions(hourly),
        const SizedBox(height: 16),
        _buildSoilMoistureChart(hourly),
        const SizedBox(height: 16),
        _buildSoilTemperatureChart(hourly),
        const SizedBox(height: 16),
        _buildEvapotranspirationCard(hourly, daily),
        const SizedBox(height: 16),
        _buildVPDCard(hourly),
        const SizedBox(height: 16),
        _buildWeeklyForecast(daily),
        const SizedBox(height: 16),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildCurrentConditions(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    if (times == null || times.isEmpty) return const SizedBox();

    // Get current hour data (first entry)
    final soilMoisture0 =
        (hourly['soil_moisture_0_to_1cm'] as List<dynamic>?)?[0] as double?;
    final soilTemp0 =
        (hourly['soil_temperature_0cm'] as List<dynamic>?)?[0] as double?;
    final vpd =
        (hourly['vapour_pressure_deficit'] as List<dynamic>?)?[0] as double?;
    final et0 =
        (hourly['et0_fao_evapotranspiration'] as List<dynamic>?)?[0] as double?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.sprout,
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
              'Surface Soil Moisture',
              soilMoisture0 != null
                  ? '${(soilMoisture0 * 100).toStringAsFixed(1)}%'
                  : 'N/A',
              soilMoisture0 != null
                  ? AgricultureService.getSoilMoistureCategory(soilMoisture0)
                  : '',
            ),
            const Divider(height: 24),
            _buildConditionRow(
              'Surface Temperature',
              soilTemp0 != null ? '${soilTemp0.toStringAsFixed(1)}°C' : 'N/A',
              '',
            ),
            const Divider(height: 24),
            _buildConditionRow(
              'VPD (Transpiration)',
              vpd != null ? '${vpd.toStringAsFixed(2)} kPa' : 'N/A',
              vpd != null ? AgricultureService.getVPDCategory(vpd) : '',
            ),
            const Divider(height: 24),
            _buildConditionRow(
              'ET₀ Reference',
              et0 != null ? '${et0.toStringAsFixed(2)} mm/h' : 'N/A',
              'Water evaporation rate',
            ),
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
              Text(label, style: context.textTheme.bodyMedium),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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

  Widget _buildSoilMoistureChart(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    final moisture0 = hourly['soil_moisture_0_to_1cm'] as List<dynamic>?;
    final moisture3 = hourly['soil_moisture_1_to_3cm'] as List<dynamic>?;
    final moisture9 = hourly['soil_moisture_3_to_9cm'] as List<dynamic>?;

    if (times == null ||
        moisture0 == null ||
        moisture3 == null ||
        moisture9 == null) {
      return const SizedBox();
    }

    // Take first 48 hours
    final dataPoints = times.length > 48 ? 48 : times.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soil Moisture (48h Forecast)',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Volumetric water content at different depths',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.1,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 12,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= times.length)
                            return const Text('');
                          final time = DateTime.parse(
                            times[value.toInt()] as String,
                          );
                          return Text(
                            DateFormat('HH:mm').format(time),
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _buildLineData(
                      moisture0,
                      dataPoints,
                      Colors.brown,
                      '0-1cm',
                    ),
                    _buildLineData(
                      moisture3,
                      dataPoints,
                      Colors.orange,
                      '1-3cm',
                    ),
                    _buildLineData(
                      moisture9,
                      dataPoints,
                      Colors.green,
                      '3-9cm',
                    ),
                  ],
                  minY: 0,
                  maxY: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend([
              ('0-1cm', Colors.brown),
              ('1-3cm', Colors.orange),
              ('3-9cm', Colors.green),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSoilTemperatureChart(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>?;
    final temp0 = hourly['soil_temperature_0cm'] as List<dynamic>?;
    final temp6 = hourly['soil_temperature_6cm'] as List<dynamic>?;
    final temp18 = hourly['soil_temperature_18cm'] as List<dynamic>?;

    if (times == null || temp0 == null || temp6 == null || temp18 == null) {
      return const SizedBox();
    }

    final dataPoints = times.length > 48 ? 48 : times.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soil Temperature (48h Forecast)',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Temperature at different soil depths',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}°C',
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 12,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= times.length)
                            return const Text('');
                          final time = DateTime.parse(
                            times[value.toInt()] as String,
                          );
                          return Text(
                            DateFormat('HH:mm').format(time),
                            style: context.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _buildLineData(temp0, dataPoints, Colors.red, '0cm'),
                    _buildLineData(temp6, dataPoints, Colors.orange, '6cm'),
                    _buildLineData(temp18, dataPoints, Colors.blue, '18cm'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend([
              ('Surface (0cm)', Colors.red),
              ('6cm depth', Colors.orange),
              ('18cm depth', Colors.blue),
            ]),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLineData(
    List<dynamic> data,
    int dataPoints,
    Color color,
    String label,
  ) {
    return LineChartBarData(
      spots: List.generate(dataPoints, (index) {
        final value = data[index];
        return FlSpot(index.toDouble(), value is num ? value.toDouble() : 0);
      }),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _buildLegend(List<(String, Color)> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: item.$2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(item.$1, style: context.textTheme.bodySmall),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEvapotranspirationCard(
    Map<String, dynamic> hourly,
    Map<String, dynamic> daily,
  ) {
    final dailyET0 = daily['et0_fao_evapotranspiration'] as List<dynamic>?;
    if (dailyET0 == null || dailyET0.isEmpty) return const SizedBox();

    final todayET0 = dailyET0[0] as double?;
    if (todayET0 == null) return const SizedBox();

    final recommendation = AgricultureService.getET0Recommendation(todayET0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.droplet,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Evapotranspiration (ET₀)',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Today: ${todayET0.toStringAsFixed(2)} mm',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ET₀ represents the water loss from a well-watered grass field. '
              'It\'s used to calculate crop irrigation requirements. '
              'Higher values indicate greater water demand.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVPDCard(Map<String, dynamic> hourly) {
    final vpd = hourly['vapour_pressure_deficit'] as List<dynamic>?;
    if (vpd == null || vpd.isEmpty) return const SizedBox();

    final currentVPD = vpd[0] as double?;
    if (currentVPD == null) return const SizedBox();

    final category = AgricultureService.getVPDCategory(currentVPD);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.wind,
                  color: context.theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vapour Pressure Deficit',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${currentVPD.toStringAsFixed(2)} kPa',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'VPD measures the difference between moisture in the air and '
              'what it can hold. Low VPD (<0.4 kPa) slows plant transpiration. '
              'High VPD (>1.6 kPa) causes plant stress.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyForecast(Map<String, dynamic> daily) {
    final times = daily['time'] as List<dynamic>?;
    final et0 = daily['et0_fao_evapotranspiration'] as List<dynamic>?;
    final precip = daily['precipitation_sum'] as List<dynamic>?;
    final tempMax = daily['temperature_2m_max'] as List<dynamic>?;
    final tempMin = daily['temperature_2m_min'] as List<dynamic>?;

    if (times == null ||
        et0 == null ||
        precip == null ||
        tempMax == null ||
        tempMin == null) {
      return const SizedBox();
    }

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
              final et0Val = et0[index] as double?;
              final precipVal = precip[index] as double?;
              final maxTemp = tempMax[index] as double?;
              final minTemp = tempMin[index] as double?;

              double? gdd;
              if (maxTemp != null && minTemp != null) {
                gdd = AgricultureService.calculateGDD(maxTemp, minTemp);
              }

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
                            if (maxTemp != null && minTemp != null)
                              Text(
                                '${maxTemp.toInt()}° / ${minTemp.toInt()}°',
                                style: context.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ET₀: ${et0Val?.toStringAsFixed(1) ?? 'N/A'} mm',
                              style: context.textTheme.bodySmall,
                            ),
                            Text(
                              'Rain: ${precipVal?.toStringAsFixed(1) ?? 'N/A'} mm',
                              style: context.textTheme.bodySmall,
                            ),
                            if (gdd != null)
                              Text(
                                'GDD: ${gdd.toStringAsFixed(0)}',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context
                                      .theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
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
                  'About Agriculture Data',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Agricultural weather data from Open-Meteo provides essential '
              'metrics for farming and crop management.',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'ET₀',
              'Reference evapotranspiration for irrigation planning',
            ),
            _buildInfoRow(
              'VPD',
              'Vapour pressure deficit affects plant transpiration',
            ),
            _buildInfoRow('GDD', 'Growing degree days track crop development'),
            _buildInfoRow(
              'Soil Data',
              'Temperature and moisture at multiple depths',
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
}
