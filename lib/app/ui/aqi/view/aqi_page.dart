import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:dio/dio.dart';

class AqiPage extends StatefulWidget {
  const AqiPage({super.key});

  @override
  State<AqiPage> createState() => _AqiPageState();
}

class _AqiPageState extends State<AqiPage> {
  final weatherController = Get.put(WeatherController());
  Map<String, dynamic>? aqiData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchAqiData();
  }

  Future<void> _fetchAqiData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final lat = weatherController.location.lat;
    final lon = weatherController.location.lon;

    if (lat == null || lon == null) {
      setState(() {
        error = 'Location not available';
        isLoading = false;
      });
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://air-quality-api.open-meteo.com/v1/air-quality',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'hourly':
              'pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,aerosol_optical_depth,dust,uv_index,uv_index_clear_sky,ammonia,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen',
          'current':
              'european_aqi,us_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,aerosol_optical_depth,dust,uv_index,uv_index_clear_sky,ammonia,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen',
          'timezone': 'auto',
          'forecast_days': 1,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          aqiData = response.data;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load air quality data';
        isLoading = false;
      });
      debugPrint('Error fetching AQI data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refreshCw),
            onPressed: _fetchAqiData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 64,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            const Gap(16),
            Text(error!, style: context.textTheme.titleMedium),
            const Gap(16),
            TextButton.icon(
              onPressed: _fetchAqiData,
              icon: Icon(LucideIcons.refreshCw),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (aqiData == null) {
      return const Center(child: Text('No data available'));
    }

    final current = aqiData!['current'];
    final europeanAqi = current['european_aqi']?.toInt() ?? 0;
    final ukDaqi = _calculateUkDaqi(current);

    return RefreshIndicator(
      onRefresh: _fetchAqiData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainAqiCard(europeanAqi, ukDaqi),
          const Gap(16),
          _buildPollutantsCard(current),
          const Gap(16),
          _buildPollenCard(current),
          const Gap(16),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildMainAqiCard(int europeanAqi, int ukDaqi) {
    final aqiInfo = _getEuropeanAqiInfo(europeanAqi);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(LucideIcons.wind, color: aqiInfo['color'], size: 32),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'European AQI',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        aqiInfo['label'],
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: aqiInfo['color'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$europeanAqi',
                  style: context.textTheme.displaySmall?.copyWith(
                    color: aqiInfo['color'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(16),
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF50F0E6),
                    Color(0xFF50CCAA),
                    Color(0xFFF0E641),
                    Color(0xFFFF5050),
                    Color(0xFFC850C8),
                    Color(0xFF7D2181),
                  ],
                ),
              ),
            ),
            const Gap(12),
            Text(
              aqiInfo['description'],
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'UK DAQI',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '$ukDaqi',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getUkDaqiInfo(ukDaqi)['color'],
                      ),
                    ),
                    Text(
                      _getUkDaqiInfo(ukDaqi)['label'],
                      style: context.textTheme.bodySmall?.copyWith(
                        color: _getUkDaqiInfo(ukDaqi)['color'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollutantsCard(Map<String, dynamic> current) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.droplets,
                  color: context.theme.colorScheme.primary,
                ),
                const Gap(12),
                Text(
                  'Pollutants',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(16),
            _buildPollutantItem(
              'PM2.5',
              'Fine Particles',
              current['pm2_5'],
              'µg/m³',
              LucideIcons.dot,
            ),
            _buildPollutantItem(
              'PM10',
              'Coarse Particles',
              current['pm10'],
              'µg/m³',
              LucideIcons.circle,
            ),
            _buildPollutantItem(
              'NO₂',
              'Nitrogen Dioxide',
              current['nitrogen_dioxide'],
              'µg/m³',
              LucideIcons.zap,
            ),
            _buildPollutantItem(
              'O₃',
              'Ozone',
              current['ozone'],
              'µg/m³',
              LucideIcons.sun,
            ),
            _buildPollutantItem(
              'SO₂',
              'Sulphur Dioxide',
              current['sulphur_dioxide'],
              'µg/m³',
              LucideIcons.cloud,
            ),
            _buildPollutantItem(
              'CO',
              'Carbon Monoxide',
              current['carbon_monoxide'],
              'µg/m³',
              LucideIcons.wind,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollutantItem(
    String symbol,
    String name,
    dynamic value,
    String unit,
    IconData icon,
  ) {
    final displayValue = value != null ? value.toStringAsFixed(1) : 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
          const Gap(12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  name,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              value != null ? '$displayValue $unit' : 'N/A',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollenCard(Map<String, dynamic> current) {
    final pollens = {
      'Grass': current['grass_pollen'],
      'Birch': current['birch_pollen'],
      'Alder': current['alder_pollen'],
      'Ragweed': current['ragweed_pollen'],
      'Mugwort': current['mugwort_pollen'],
      'Olive': current['olive_pollen'],
    };

    // Check if any pollen data is available
    final hasData = pollens.values.any((value) => value != null && value > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.flower,
                  color: context.theme.colorScheme.primary,
                ),
                const Gap(12),
                Text(
                  'Pollen Levels',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(16),
            if (!hasData)
              Text(
                'No significant pollen activity detected',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...pollens.entries.map((entry) {
                if (entry.value == null || entry.value <= 0) {
                  return const SizedBox.shrink();
                }
                return _buildPollenItem(entry.key, entry.value);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPollenItem(String name, dynamic value) {
    final level = _getPollenLevel(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, style: context.textTheme.bodyMedium)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: level['color'].withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: level['color'], width: 1),
            ),
            child: Text(
              level['label'],
              style: context.textTheme.bodySmall?.copyWith(
                color: level['color'],
                fontWeight: FontWeight.bold,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.info,
                  color: context.theme.colorScheme.primary,
                ),
                const Gap(12),
                Text(
                  'About European AQI',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Gap(12),
            Text(
              'The European Air Quality Index (EAQI) provides information about air quality based on concentration levels of key pollutants. The scale ranges from 0 (excellent) to >100 (extremely poor).',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(12),
            Text(
              'Data source: Open-Meteo Air Quality API',
              style: context.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getEuropeanAqiInfo(int aqi) {
    if (aqi <= 20) {
      return {
        'label': 'Excellent',
        'color': const Color(0xFF50F0E6),
        'description':
            'Air quality is excellent. Ideal time for outdoor activities.',
      };
    } else if (aqi <= 40) {
      return {
        'label': 'Good',
        'color': const Color(0xFF50CCAA),
        'description':
            'Air quality is good. Suitable for all outdoor activities.',
      };
    } else if (aqi <= 60) {
      return {
        'label': 'Fair',
        'color': const Color(0xFFF0E641),
        'description':
            'Air quality is acceptable. Sensitive individuals should consider reducing prolonged outdoor activities.',
      };
    } else if (aqi <= 80) {
      return {
        'label': 'Poor',
        'color': const Color(0xFFFF5050),
        'description':
            'Air quality is poor. Sensitive groups may experience health effects.',
      };
    } else if (aqi <= 100) {
      return {
        'label': 'Very Poor',
        'color': const Color(0xFFC850C8),
        'description':
            'Air quality is very poor. Everyone may experience health effects.',
      };
    } else {
      return {
        'label': 'Extremely Poor',
        'color': const Color(0xFF7D2181),
        'description':
            'Air quality is extremely poor. Health alert - everyone may experience serious health effects.',
      };
    }
  }

  int _calculateUkDaqi(Map<String, dynamic> current) {
    // Calculate UK DAQI based on pollutant concentrations
    // UK DAQI uses the highest band from all pollutants
    final o3 = (current['ozone'] ?? 0).toDouble(); // µg/m³
    final no2 = (current['nitrogen_dioxide'] ?? 0).toDouble(); // µg/m³
    final so2 = (current['sulphur_dioxide'] ?? 0).toDouble(); // µg/m³
    final pm25 = (current['pm2_5'] ?? 0).toDouble(); // µg/m³
    final pm10 = (current['pm10'] ?? 0).toDouble(); // µg/m³

    int maxBand = 1;

    // O3 bands (8-hour mean in µg/m³)
    if (o3 > 240)
      maxBand = 10;
    else if (o3 > 213)
      maxBand = maxBand > 9 ? maxBand : 9;
    else if (o3 > 187)
      maxBand = maxBand > 8 ? maxBand : 8;
    else if (o3 > 160)
      maxBand = maxBand > 7 ? maxBand : 7;
    else if (o3 > 133)
      maxBand = maxBand > 6 ? maxBand : 6;
    else if (o3 > 107)
      maxBand = maxBand > 5 ? maxBand : 5;
    else if (o3 > 80)
      maxBand = maxBand > 4 ? maxBand : 4;

    // NO2 bands (hourly mean in µg/m³)
    if (no2 > 600)
      maxBand = 10;
    else if (no2 > 534)
      maxBand = maxBand > 9 ? maxBand : 9;
    else if (no2 > 467)
      maxBand = maxBand > 8 ? maxBand : 8;
    else if (no2 > 400)
      maxBand = maxBand > 7 ? maxBand : 7;
    else if (no2 > 334)
      maxBand = maxBand > 6 ? maxBand : 6;
    else if (no2 > 267)
      maxBand = maxBand > 5 ? maxBand : 5;
    else if (no2 > 200)
      maxBand = maxBand > 4 ? maxBand : 4;

    // SO2 bands (15-min mean in µg/m³)
    if (so2 > 1064)
      maxBand = 10;
    else if (so2 > 887)
      maxBand = maxBand > 9 ? maxBand : 9;
    else if (so2 > 710)
      maxBand = maxBand > 8 ? maxBand : 8;
    else if (so2 > 532)
      maxBand = maxBand > 7 ? maxBand : 7;
    else if (so2 > 354)
      maxBand = maxBand > 6 ? maxBand : 6;
    else if (so2 > 266)
      maxBand = maxBand > 5 ? maxBand : 5;
    else if (so2 > 177)
      maxBand = maxBand > 4 ? maxBand : 4;

    // PM2.5 bands (24-hour mean in µg/m³)
    if (pm25 > 70)
      maxBand = 10;
    else if (pm25 > 64)
      maxBand = maxBand > 9 ? maxBand : 9;
    else if (pm25 > 58)
      maxBand = maxBand > 8 ? maxBand : 8;
    else if (pm25 > 53)
      maxBand = maxBand > 7 ? maxBand : 7;
    else if (pm25 > 47)
      maxBand = maxBand > 6 ? maxBand : 6;
    else if (pm25 > 41)
      maxBand = maxBand > 5 ? maxBand : 5;
    else if (pm25 > 35)
      maxBand = maxBand > 4 ? maxBand : 4;

    // PM10 bands (24-hour mean in µg/m³)
    if (pm10 > 100)
      maxBand = 10;
    else if (pm10 > 91)
      maxBand = maxBand > 9 ? maxBand : 9;
    else if (pm10 > 83)
      maxBand = maxBand > 8 ? maxBand : 8;
    else if (pm10 > 75)
      maxBand = maxBand > 7 ? maxBand : 7;
    else if (pm10 > 67)
      maxBand = maxBand > 6 ? maxBand : 6;
    else if (pm10 > 58)
      maxBand = maxBand > 5 ? maxBand : 5;
    else if (pm10 > 50)
      maxBand = maxBand > 4 ? maxBand : 4;

    return maxBand;
  }

  Map<String, dynamic> _getUkDaqiInfo(int daqi) {
    // UK Daily Air Quality Index (1-10 scale)
    if (daqi <= 3) {
      return {'label': 'Low', 'color': const Color(0xFF9CFF9C)};
    } else if (daqi <= 6) {
      return {'label': 'Moderate', 'color': const Color(0xFFFFFF31)};
    } else if (daqi <= 9) {
      return {'label': 'High', 'color': const Color(0xFFFF9C31)};
    } else {
      return {'label': 'Very High', 'color': const Color(0xFFFF3131)};
    }
  }

  Map<String, dynamic> _getPollenLevel(dynamic value) {
    final val = value.toDouble();
    if (val < 20) {
      return {'label': 'Low', 'color': const Color(0xFF50CCAA)};
    } else if (val < 50) {
      return {'label': 'Moderate', 'color': const Color(0xFFF0E641)};
    } else if (val < 100) {
      return {'label': 'High', 'color': const Color(0xFFFF5050)};
    } else {
      return {'label': 'Very High', 'color': const Color(0xFFC850C8)};
    }
  }
}
