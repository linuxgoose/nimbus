import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/ui/places/widgets/place_action.dart';
import 'package:nimbus/app/ui/widgets/weather/daily/daily_card_list.dart';
import 'package:nimbus/app/ui/widgets/weather/daily/daily_container.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/desc_container.dart';
import 'package:nimbus/app/ui/widgets/weather/hourly.dart';
import 'package:nimbus/app/ui/widgets/weather/now.dart';
import 'package:nimbus/app/ui/widgets/weather/sunset_sunrise.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class PlaceInfo extends StatefulWidget {
  const PlaceInfo({super.key, required this.weatherCard});
  final WeatherCard weatherCard;

  @override
  State<PlaceInfo> createState() => _PlaceInfoState();
}

class _PlaceInfoState extends State<PlaceInfo> {
  int timeNow = 0;
  int dayNow = 0;
  final weatherController = Get.put(WeatherController());
  final itemScrollController = ItemScrollController();

  @override
  void initState() {
    getTime();
    super.initState();
  }

  void getTime() {
    final weatherCard = widget.weatherCard;

    // Add null safety checks
    if (weatherCard.time == null ||
        weatherCard.time!.isEmpty ||
        weatherCard.timeDaily == null ||
        weatherCard.timeDaily!.isEmpty ||
        weatherCard.timezone == null) {
      debugPrint('⚠️ PlaceInfo: Missing required weather data');
      return;
    }

    timeNow = weatherController.getTime(
      weatherCard.time!,
      weatherCard.timezone!,
    );
    dayNow = weatherController.getDay(
      weatherCard.timeDaily!,
      weatherCard.timezone!,
    );
    Future.delayed(
      const Duration(milliseconds: 30),
      () => itemScrollController.scrollTo(
        index: timeNow,
        duration: const Duration(seconds: 2),
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weatherCard = widget.weatherCard;

    // Check if essential data is available
    if (weatherCard.time == null ||
        weatherCard.time!.isEmpty ||
        weatherCard.weathercode == null ||
        weatherCard.temperature2M == null ||
        weatherCard.sunrise == null ||
        weatherCard.sunset == null ||
        weatherCard.temperature2MMax == null ||
        weatherCard.temperature2MMin == null) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
          ),
          title: Text(
            weatherCard.district != null && weatherCard.district!.isNotEmpty
                ? '${weatherCard.city}, ${weatherCard.district}'
                : '${weatherCard.city}',
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.cloudOff, size: 64),
              const SizedBox(height: 16),
              Text(
                'Weather data unavailable',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Try refreshing or check your data source',
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handleRefresh,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: Scaffold(
        appBar: _buildAppBar(context, weatherCard),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              children: [
                _buildNowWidget(weatherCard),
                _buildHourlyList(weatherCard),
                _buildSunsetSunriseWidget(weatherCard),
                _buildHourlyDescContainer(weatherCard),
                _buildDailyContainer(weatherCard),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await weatherController.updateCard(widget.weatherCard);
    getTime();
    setState(() {});
  }

  AppBar _buildAppBar(BuildContext context, WeatherCard weatherCard) => AppBar(
    centerTitle: true,
    automaticallyImplyLeading: false,
    leading: IconButton(
      onPressed: () => Get.back(),
      icon: const Icon(LucideIcons.arrowLeft, size: 20),
    ),
    title: Text(
      weatherCard.district!.isNotEmpty
          ? '${weatherCard.city}, ${weatherCard.district}'
          : '${weatherCard.city}',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    actions: [
      IconButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            enableDrag: false,
            builder: (BuildContext context) =>
                PlaceAction(edit: true, card: weatherCard),
          );
          getTime();
          setState(() {});
        },
        icon: Icon(LucideIcons.pencil, size: 18),
      ),
    ],
  );

  Widget _buildNowWidget(WeatherCard weatherCard) {
    // Safely access nullable fields with defaults
    final timeNowIndex = timeNow < (weatherCard.time?.length ?? 0)
        ? timeNow
        : 0;
    final dayNowIndex = dayNow < (weatherCard.sunrise?.length ?? 0)
        ? dayNow
        : 0;

    return Now(
      time: weatherCard.time?[timeNowIndex] ?? '',
      weather: weatherCard.weathercode?[timeNowIndex],
      degree: weatherCard.temperature2M?[timeNowIndex],
      feels:
          weatherCard.apparentTemperature?[timeNowIndex] ??
          weatherCard.temperature2M?[timeNowIndex] ??
          0.0,
      timeDay: weatherCard.sunrise?[dayNowIndex] ?? '',
      timeNight: weatherCard.sunset?[dayNowIndex] ?? '',
      tempMax: weatherCard.temperature2MMax?[dayNowIndex] ?? 0.0,
      tempMin: weatherCard.temperature2MMin?[dayNowIndex] ?? 0.0,
    );
  }

  Widget _buildHourlyList(WeatherCard weatherCard) => Card(
    margin: const EdgeInsets.only(bottom: 15),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: SizedBox(
        height: 135,
        child: ScrollablePositionedList.separated(
          key: const PageStorageKey(1),
          separatorBuilder: (BuildContext context, int index) =>
              const VerticalDivider(width: 10, indent: 40, endIndent: 40),
          scrollDirection: Axis.horizontal,
          itemScrollController: itemScrollController,
          itemCount: weatherCard.time!.length,
          itemBuilder: (ctx, i) => _buildHourlyItem(weatherCard, i),
        ),
      ),
    ),
  );

  Widget _buildHourlyItem(WeatherCard weatherCard, int i) => GestureDetector(
    onTap: () {
      timeNow = i;
      dayNow = (i / 24).floor();
      setState(() {});
    },
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: i == timeNow
            ? context.theme.colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Hourly(
        time: weatherCard.time![i],
        weather: weatherCard.weathercode![i],
        degree: weatherCard.temperature2M![i],
        timeDay: weatherCard.sunrise![(i / 24).floor()],
        timeNight: weatherCard.sunset![(i / 24).floor()],
      ),
    ),
  );

  Widget _buildSunsetSunriseWidget(WeatherCard weatherCard) {
    final dayNowIndex = dayNow < (weatherCard.sunrise?.length ?? 0)
        ? dayNow
        : 0;

    return SunsetSunrise(
      timeSunrise: weatherCard.sunrise?[dayNowIndex] ?? '',
      timeSunset: weatherCard.sunset?[dayNowIndex] ?? '',
    );
  }

  Widget _buildHourlyDescContainer(WeatherCard weatherCard) => DescContainer(
    humidity: weatherCard.relativehumidity2M?[timeNow],
    wind: weatherCard.windspeed10M?[timeNow],
    visibility: weatherCard.visibility?[timeNow],
    feels: weatherCard.apparentTemperature?[timeNow],
    evaporation: weatherCard.evapotranspiration?[timeNow],
    precipitation: weatherCard.precipitation?[timeNow],
    direction: weatherCard.winddirection10M?[timeNow],
    pressure: weatherCard.surfacePressure?[timeNow],
    rain: weatherCard.rain?[timeNow],
    cloudcover: weatherCard.cloudcover?[timeNow],
    windgusts: weatherCard.windgusts10M?[timeNow],
    uvIndex: weatherCard.uvIndex?[timeNow],
    dewpoint2M: weatherCard.dewpoint2M?[timeNow],
    precipitationProbability: weatherCard.precipitationProbability?[timeNow],
    shortwaveRadiation: weatherCard.shortwaveRadiation?[timeNow],
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
}
