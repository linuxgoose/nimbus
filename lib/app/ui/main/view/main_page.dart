import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:nimbus/app/api/api.dart'; // Import to use WeatherAPI
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/ui/widgets/weather/daily/daily_card_list.dart';
import 'package:nimbus/app/ui/widgets/weather/daily/daily_container.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/desc_container.dart';
import 'package:nimbus/app/ui/widgets/weather/hourly.dart';
import 'package:nimbus/app/ui/widgets/weather/now.dart';
import 'package:nimbus/app/ui/widgets/shimmer.dart';
import 'package:nimbus/app/ui/widgets/weather/sunset_sunrise.dart';
import 'package:nimbus/app/ui/radar/view/radar_page.dart';
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
        final dayOfNow = weatherController.dayOfNow.value;
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
  ) => ListView(
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
      _buildRadarTile(),
      _buildHourlyList(context, mainWeather, hourOfDay, dayOfNow),
      _buildSunsetSunriseWidget(sunrise, sunset),
      _buildHourlyDescContainer(mainWeather, hourOfDay),
      _buildDailyContainer(weatherCard),
    ],
  );

  Widget _buildWeatherAlert() {
    final lat = weatherController.location.lat;
    final lon = weatherController.location.lon;

    // 1. Safety check: If coordinates are missing, return an empty space immediately.
    if (lat == null || lon == null) return const SizedBox.shrink();

    return FutureBuilder<List<dynamic>>(
      // Note: In a real app, you might want to store this future in a variable
      // to avoid re-fetching on every small UI rebuild.
      future: WeatherAPI().getRawAlerts(lat, lon),
      builder: (context, snapshot) {
        // 2. Handle the loading state - don't show shimmer to avoid layout shift
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        // 3. Handle errors or empty data
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        try {
          final alert = snapshot.data!.first;
          // 4. Use null-coalescing (??) to ensure no property access crashes the app
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

          return Container(
            margin: const EdgeInsets.only(bottom: 15, top: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: warningColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(IconsaxPlusLinear.danger, color: warningColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alertTitle,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: warningColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alertDesc,
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
        } catch (e) {
          // 5. Catch-all for parsing errors to prevent the screen from going red
          return const SizedBox.shrink();
        }
      },
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
    weather: mainWeather.weathercode![hourOfDay],
    degree: mainWeather.temperature2M![hourOfDay],
    feels: mainWeather.apparentTemperature![hourOfDay]!,
    timeDay: sunrise,
    timeNight: sunset,
    tempMax: tempMax,
    tempMin: tempMin,
    humidity: mainWeather.relativehumidity2M?[hourOfDay],
    windSpeed: mainWeather.windspeed10M?[hourOfDay],
    precipitationProbability: mainWeather.precipitationProbability?[hourOfDay],
    uvIndex: mainWeather.uvIndex?[hourOfDay]?.round(),
  );

  Widget _buildHourlyList(
    BuildContext context,
    MainWeatherCache mainWeather,
    int hourOfDay,
    int dayOfNow,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: SizedBox(
        height: 135,
        child: ScrollablePositionedList.separated(
          key: const PageStorageKey(0),
          separatorBuilder: (BuildContext context, int index) =>
              const VerticalDivider(width: 10, indent: 40, endIndent: 40),
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

    return GestureDetector(
      onTap: () {
        weatherController.hourOfDay.value = i;
        weatherController.dayOfNow.value = i24;
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: i == hourOfDay
              ? context.theme.colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Hourly(
          time: mainWeather.time![i],
          weather: mainWeather.weathercode![i],
          degree: mainWeather.temperature2M![i],
          timeDay: mainWeather.sunrise![i24],
          timeNight: mainWeather.sunset![i24],
        ),
      ),
    );
  }

  Widget _buildSunsetSunriseWidget(String sunrise, String sunset) =>
      SunsetSunrise(timeSunrise: sunrise, timeSunset: sunset);

  Widget _buildHourlyDescContainer(
    MainWeatherCache mainWeather,
    int hourOfDay,
  ) => DescContainer(
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
    precipitationProbability: mainWeather.precipitationProbability?[hourOfDay],
    shortwaveRadiation: mainWeather.shortwaveRadiation?[hourOfDay],
    initiallyExpanded: false,
    title: 'hourlyVariables'.tr,
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
                IconsaxPlusLinear.radar,
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
              IconsaxPlusLinear.arrow_right_3,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}
