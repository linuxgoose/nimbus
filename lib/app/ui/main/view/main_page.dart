import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/api/api.dart'; // Import to use WeatherAPI
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';
import 'package:nimbus/app/ui/widgets/weather/daily/daily_card_list.dart';
import 'package:nimbus/app/ui/widgets/weather/daily/daily_container.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/desc_container.dart';
import 'package:nimbus/app/ui/widgets/weather/hourly.dart';
import 'package:nimbus/app/ui/widgets/weather/now.dart';
import 'package:nimbus/app/ui/widgets/shimmer.dart';
import 'package:nimbus/app/ui/widgets/weather/sunset_sunrise.dart';
import 'package:nimbus/app/ui/widgets/weather/rain_forecast_chart.dart';
import 'package:nimbus/app/ui/radar/view/radar_page.dart';
import 'package:nimbus/app/ui/aqi/view/aqi_page.dart';
import 'package:nimbus/app/ui/tides/view/tides_page.dart';
import 'package:nimbus/app/ui/elevation/view/elevation_page.dart';
import 'package:nimbus/app/ui/aurora/view/aurora_page.dart';
import 'package:nimbus/app/ui/moon/moon_phase_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final weatherController = Get.put(WeatherController());

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _handleRefresh,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Obx(() {
        if (weatherController.isLoading.isTrue) {
          return _buildLoadingView();
        }

        final mainWeather = weatherController.mainWeather;
        final weatherCard = WeatherCard.fromJson(mainWeather.toJson());
        final hourOfDay = weatherController.hourOfDay.value;
        var dayOfNow = weatherController.dayOfNow.value;

        // Ensure dayOfNow is within valid bounds for all arrays
        final sunriseLen = mainWeather.sunrise?.length ?? 0;
        final sunsetLen = mainWeather.sunset?.length ?? 0;
        final tempMaxLen = mainWeather.temperature2MMax?.length ?? 0;
        final tempMinLen = mainWeather.temperature2MMin?.length ?? 0;

        if (sunriseLen == 0 ||
            sunsetLen == 0 ||
            tempMaxLen == 0 ||
            tempMinLen == 0) {
          return _buildLoadingView();
        }

        final maxDayIndex =
            [
              sunriseLen,
              sunsetLen,
              tempMaxLen,
              tempMinLen,
            ].reduce((a, b) => a < b ? a : b) -
            1;

        if (maxDayIndex < 0 || dayOfNow > maxDayIndex || dayOfNow < 0) {
          dayOfNow = 0;
        }

        final sunrise = mainWeather.sunrise![dayOfNow];
        final sunset = mainWeather.sunset![dayOfNow];
        final tempMax = mainWeather.temperature2MMax![dayOfNow];
        final tempMin = mainWeather.temperature2MMin![dayOfNow];

        return _buildMainView(
          context,
          mainWeather,
          weatherCard,
          hourOfDay,
          dayOfNow,
          sunrise,
          sunset,
          tempMax!,
          tempMin!,
        );
      }),
    ),
  );

  Future<void> _handleRefresh() async {
    await weatherController.deleteAll(false);
    await weatherController.setLocation();
    setState(() {});
  }

  Widget _buildLoadingView() => ListView(
    children: const [
      MyShimmer(height: 200),
      MyShimmer(height: 130, margin: EdgeInsets.symmetric(vertical: 15)),
      MyShimmer(height: 90, margin: EdgeInsets.only(bottom: 15)),
      MyShimmer(height: 400, margin: EdgeInsets.only(bottom: 15)),
      MyShimmer(height: 450, margin: EdgeInsets.only(bottom: 15)),
    ],
  );

  Widget _buildMainView(
    BuildContext context,
    MainWeatherCache mainWeather,
    WeatherCard weatherCard,
    int hourOfDay,
    int dayOfNow,
    String sunrise,
    String sunset,
    double tempMax,
    double tempMin,
  ) {
    debugPrint(
      'Building main view - hideRainForecast: ${settings.hideRainForecast}',
    );
    return ListView(
      children: [
        _buildNowWidget(
          mainWeather,
          hourOfDay,
          dayOfNow,
          sunrise,
          sunset,
          tempMax,
          tempMin,
        ),
        // --- REAL API ALERT WIDGET ---
        _buildWeatherAlert(),
        // ----------------------------
        if (!settings.hideRainForecast) ...[
          _buildRainForecastChart(mainWeather),
        ] else ...[
          const SizedBox.shrink(), // Debug: explicitly hidden
        ],
        _buildRadarTile(),
        if (!settings.hideAqi) _buildAqiTile(),
        if (!settings.hideTides) _buildTidesTile(),
        if (!settings.hideElevation) _buildElevationTile(),
        if (!settings.hideAurora) _buildAuroraTile(),
        _buildHourlyList(context, mainWeather, hourOfDay, dayOfNow),
        _buildSunsetSunriseWidget(sunrise, sunset),
        _buildHourlyDescContainer(mainWeather, hourOfDay),
        _buildDailyContainer(weatherCard),
        const MoonPhaseTile(),
      ],
    );
  }

  Widget _buildWeatherAlert() {
    // Check if alerts should be shown on main page
    if (!settings.showAlertsOnMainPage) {
      return const SizedBox.shrink();
    }

    // Check if dummy alerts should be shown
    if (settings.showDummyAlerts) {
      return _buildDummyAlert();
    }

    // Otherwise show real API alerts
    final lat = weatherController.location.lat;
    final lon = weatherController.location.lon;

    // Safety check: If coordinates are missing, return an empty space immediately.
    if (lat == null || lon == null) return const SizedBox.shrink();

    return FutureBuilder<List<dynamic>>(
      future: WeatherAPI().getRawAlerts(lat, lon),
      builder: (context, snapshot) {
        // Handle the loading state - don't show shimmer to avoid layout shift
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        // Handle errors or empty data
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        try {
          final alerts = snapshot.data!;
          if (alerts.isEmpty) return const SizedBox.shrink();

          // Filter alerts by minimum severity setting
          final filteredAlerts = _filterAlertsBySeverity(alerts);
          if (filteredAlerts.isEmpty) return const SizedBox.shrink();

          final alert = filteredAlerts.first;
          final String alertTitle =
              alert['event']?.toString() ?? "Weather Warning";
          final String alertDesc =
              alert['description']?.toString() ?? "No description provided.";
          final String severity = (alert['severity']?.toString() ?? 'moderate')
              .toLowerCase();

          Color warningColor;
          switch (severity) {
            case 'extreme':
              warningColor = Colors.red;
              break;
            case 'severe':
              warningColor = Colors.orange;
              break;
            case 'moderate':
              warningColor = Colors.amber.shade700;
              break;
            default:
              warningColor = Colors.blue;
          }

          // Store alert in history
          _storeAlertInHistory(alert, lat, lon);

          return _buildAlertContainer(alertTitle, alertDesc, warningColor);
        } catch (e) {
          // Catch-all for parsing errors to prevent the screen from going red
          return const SizedBox.shrink();
        }
      },
    );
  }

  List<dynamic> _filterAlertsBySeverity(List<dynamic> alerts) {
    if (settings.alertMinSeverity == 'all') return alerts;

    final severityLevels = ['minor', 'moderate', 'severe', 'extreme'];
    final minLevel = settings.alertMinSeverity;
    final minIndex = severityLevels.indexOf(minLevel);

    return alerts.where((alert) {
      final severity = (alert['severity']?.toString() ?? 'moderate')
          .toLowerCase();
      final severityIndex = severityLevels.indexOf(severity);
      return severityIndex >= minIndex;
    }).toList();
  }

  void _storeAlertInHistory(dynamic alert, double lat, double lon) {
    try {
      final timestamp = DateTime.now();
      final event = alert['event']?.toString() ?? 'Weather Alert';
      final severity = (alert['severity']?.toString() ?? 'moderate')
          .toLowerCase();

      // Create unique key combining location and event
      final eventKey =
          '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}_${timestamp.millisecondsSinceEpoch}_$event';

      final alertHistory = AlertHistory(
        lat: lat,
        lon: lon,
        timestamp: timestamp,
        event: event,
        description: alert['description']?.toString(),
        severity: severity,
      )..eventKey = eventKey;

      isar.writeTxnSync(() {
        isar.alertHistorys.putByEventKeySync(alertHistory);
      });
    } catch (e) {
      debugPrint('Error storing alert in history: $e');
    }
  }

  Widget _buildDummyAlert() {
    return _buildAlertContainer(
      'Severe Flood Warning',
      'Flooding is expected in low-lying areas near rivers and streams. Residents should prepare for possible evacuations and avoid travel through affected areas.',
      Colors.orange,
    );
  }

  Widget _buildAlertContainer(String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15, top: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildNowWidget(
    MainWeatherCache mainWeather,
    int hourOfDay,
    int dayOfNow,
    String sunrise,
    String sunset,
    double tempMax,
    double tempMin,
  ) => Now(
    time: mainWeather.time![hourOfDay],
    weather: mainWeather.weathercode?[hourOfDay] ?? 0,
    degree: mainWeather.temperature2M![hourOfDay],
    feels:
        (mainWeather.apparentTemperature?[hourOfDay] ??
        mainWeather.temperature2M![hourOfDay])!,
    timeDay: sunrise,
    timeNight: sunset,
    tempMax: tempMax,
    tempMin: tempMin,
    humidity: mainWeather.relativehumidity2M?[hourOfDay],
    windSpeed: mainWeather.windspeed10M?[hourOfDay],
    precipitationProbability: mainWeather.precipitationProbability?[hourOfDay],
    uvIndex: mainWeather.uvIndex?[hourOfDay]?.round(),
  );

  Widget _buildRainForecastChart(MainWeatherCache mainWeather) {
    // Get current location from the weather controller
    final latitude = weatherController.location.lat;
    final longitude = weatherController.location.lon;

    if (latitude == null || longitude == null) {
      return const SizedBox.shrink();
    }

    return RainForecastChart(latitude: latitude, longitude: longitude);
  }

  Widget _buildHourlyList(
    BuildContext context,
    MainWeatherCache mainWeather,
    int hourOfDay,
    int dayOfNow,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 15),
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: SizedBox(
        height: 130,
        child: ScrollablePositionedList.separated(
          key: const PageStorageKey(0),
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: 4),
          scrollDirection: Axis.horizontal,
          itemScrollController: weatherController.itemScrollController,
          itemCount: mainWeather.time!.length,
          itemBuilder: (ctx, i) =>
              _buildHourlyItem(context, mainWeather, i, hourOfDay, dayOfNow),
        ),
      ),
    ),
  );

  Widget _buildHourlyItem(
    BuildContext context,
    MainWeatherCache mainWeather,
    int i,
    int hourOfDay,
    int dayOfNow,
  ) {
    final i24 = (i / 24).floor();
    final isSelected = i == hourOfDay;

    return GestureDetector(
      onTap: () {
        weatherController.hourOfDay.value = i;
        weatherController.dayOfNow.value = i24;
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.theme.colorScheme.primaryContainer
              : context.theme.colorScheme.surfaceContainerHighest.withOpacity(
                  0.3,
                ),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: context.theme.colorScheme.primary.withOpacity(0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Hourly(
          time: mainWeather.time![i],
          weather: mainWeather.weathercode?[i] ?? 0,
          degree: mainWeather.temperature2M![i],
          timeDay: mainWeather.sunrise?[i24] ?? '',
          timeNight: mainWeather.sunset?[i24] ?? '',
        ),
      ),
    );
  }

  Widget _buildSunsetSunriseWidget(String sunrise, String sunset) =>
      SunsetSunrise(timeSunrise: sunrise, timeSunset: sunset);

  Widget _buildHourlyDescContainer(
    MainWeatherCache mainWeather,
    int hourOfDay,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 15),
    elevation: 0,
    child: DescContainer(
      humidity: mainWeather.relativehumidity2M?[hourOfDay],
      wind: mainWeather.windspeed10M?[hourOfDay],
      visibility: mainWeather.visibility?[hourOfDay],
      feels: mainWeather.apparentTemperature?[hourOfDay],
      evaporation: mainWeather.evapotranspiration?[hourOfDay],
      precipitation: mainWeather.precipitation?[hourOfDay],
      direction: mainWeather.winddirection10M?[hourOfDay],
      pressure: mainWeather.surfacePressure?[hourOfDay],
      rain: mainWeather.rain?[hourOfDay],
      cloudcover: mainWeather.cloudcover?[hourOfDay],
      windgusts: mainWeather.windgusts10M?[hourOfDay],
      uvIndex: mainWeather.uvIndex?[hourOfDay],
      dewpoint2M: mainWeather.dewpoint2M?[hourOfDay],
      precipitationProbability:
          mainWeather.precipitationProbability?[hourOfDay],
      shortwaveRadiation: mainWeather.shortwaveRadiation?[hourOfDay],
      initiallyExpanded: false,
      title: 'hourlyVariables'.tr,
    ),
  );
  Widget _buildDailyContainer(WeatherCard weatherCard) => DailyContainer(
    weatherData: weatherCard,
    onTap: () => Get.to(
      () => DailyCardList(weatherData: weatherCard),
      transition: Transition.downToUp,
    ),
  );

  Widget _buildRadarTile() => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Get.to(() => const RadarPage(), transition: Transition.downToUp),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.radar,
                size: 32,
                color: context.theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weather Radar',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View live precipitation and radar imagery',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
  Widget _buildAqiTile() => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Get.to(() => const AqiPage(), transition: Transition.downToUp),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.wind,
                size: 32,
                color: context.theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Air Quality',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check air quality index and pollen levels',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildTidesTile() => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Get.to(() => const TidesPage(), transition: Transition.downToUp),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.waves,
                size: 32,
                color: context.theme.colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tides',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View tide times and heights',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildElevationTile() => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Get.to(() => const ElevationPage(), transition: Transition.downToUp),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.mountain,
                size: 32,
                color: context.theme.colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elevation',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View elevation above sea level',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildAuroraTile() => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Get.to(() => const AuroraPage(), transition: Transition.downToUp),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.sparkles,
                size: 32,
                color: context.theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aurora Watch',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Northern lights forecast and alerts',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.arrowRight,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}
