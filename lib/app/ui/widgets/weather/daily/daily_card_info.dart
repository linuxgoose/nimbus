import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/desc_container.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/message.dart';
import 'package:nimbus/app/ui/widgets/weather/hourly.dart';
import 'package:nimbus/app/ui/widgets/weather/now.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_data.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_weather.dart';
import 'package:nimbus/app/ui/widgets/weather/sunset_sunrise.dart';
import 'package:nimbus/main.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class DailyCardInfo extends StatefulWidget {
  const DailyCardInfo({
    super.key,
    required this.weatherData,
    required this.index,
  });

  final WeatherCard weatherData;
  final int index;

  @override
  State<DailyCardInfo> createState() => _DailyCardInfoState();
}

class _DailyCardInfoState extends State<DailyCardInfo> {
  final statusWeather = StatusWeather();
  final statusData = StatusData();
  final message = Message();
  late PageController pageController;
  int pageIndex = 0;
  int hourOfDay = 0;

  @override
  void initState() {
    pageController = PageController(initialPage: widget.index);
    pageIndex = widget.index;
    super.initState();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherData = widget.weatherData;
    final timeDaily = weatherData.timeDaily ?? [];

    final textTheme = context.textTheme;

    return Scaffold(
      appBar: _buildAppBar(context, textTheme, timeDaily),
      body: SafeArea(
        child: PageView.builder(
          controller: pageController,
          onPageChanged: (index) {
            setState(() {
              pageIndex = index;
              hourOfDay = 0;
            });
          },
          itemCount: timeDaily.length,
          itemBuilder: (context, index) =>
              _buildPageContent(context, weatherData, index),
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    TextTheme textTheme,
    List<DateTime> timeDaily,
  ) => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: true,
    leading: IconButton(
      onPressed: () => Get.back(),
      icon: const Icon(LucideIcons.arrowLeft, size: 20),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    title: Text(
      DateFormat.MMMMEEEEd(locale.languageCode).format(timeDaily[pageIndex]),
      style: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
  );

  Widget _buildPageContent(
    BuildContext context,
    WeatherCard weatherData,
    int index,
  ) {
    // Safety check for daily data availability
    if (weatherData.weathercodeDaily == null ||
        weatherData.weathercodeDaily!.isEmpty ||
        index >= weatherData.weathercodeDaily!.length) {
      return Container();
    }

    final weatherCodeDaily = weatherData.weathercodeDaily?[index];
    if (weatherCodeDaily == null) {
      return Container();
    }

    // Also check if daily data exists for this index
    final dailyDataLength = weatherData.timeDaily?.length ?? 0;
    if (index >= dailyDataLength) {
      return Container();
    }

    // Find the actual start index for this day's hourly data
    // by matching the day from timeDaily with the day in the hourly time array
    final targetDay = weatherData.timeDaily?[index];
    if (targetDay == null) {
      return Container();
    }

    int startIndex = -1;
    final hourlyTimes = weatherData.time ?? [];

    // Debug logging
    print(
      'Daily card info - Looking for day index: $index, target day: $targetDay',
    );
    print('Daily card info - Hourly times length: ${hourlyTimes.length}');
    if (hourlyTimes.isNotEmpty) {
      print('Daily card info - First hourly time: ${hourlyTimes.first}');
      print('Daily card info - Last hourly time: ${hourlyTimes.last}');
    }

    // Find the first hourly entry that matches this day
    for (int i = 0; i < hourlyTimes.length; i++) {
      try {
        final hourlyTime = DateTime.parse(hourlyTimes[i]);
        if (hourlyTime.year == targetDay.year &&
            hourlyTime.month == targetDay.month &&
            hourlyTime.day == targetDay.day) {
          startIndex = i;
          print(
            'Daily card info - Found start index: $startIndex for day: $targetDay',
          );
          break;
        }
      } catch (e) {
        continue;
      }
    }

    // If we couldn't find matching hourly data, return empty
    if (startIndex == -1 || startIndex >= hourlyTimes.length) {
      print(
        'Daily card info - No matching hourly data found for day: $targetDay',
      );
      return Container();
    }

    // Safety check: ensure we have hourly data for this day
    final hourlyDataLength = weatherData.time?.length ?? 0;
    if (startIndex >= hourlyDataLength) {
      return Container();
    }

    // Safe access with additional length checks for each array
    double? temperature2MMin;
    if ((weatherData.temperature2MMin?.length ?? 0) > index) {
      temperature2MMin = weatherData.temperature2MMin![index];
    }

    double? temperature2MMax;
    if ((weatherData.temperature2MMax?.length ?? 0) > index) {
      temperature2MMax = weatherData.temperature2MMax![index];
    }

    double? apparentTemperatureMin;
    if ((weatherData.apparentTemperatureMin?.length ?? 0) > index) {
      apparentTemperatureMin = weatherData.apparentTemperatureMin![index];
    }

    double? apparentTemperatureMax;
    if ((weatherData.apparentTemperatureMax?.length ?? 0) > index) {
      apparentTemperatureMax = weatherData.apparentTemperatureMax![index];
    }

    double? uvIndexMax;
    if ((weatherData.uvIndexMax?.length ?? 0) > index) {
      uvIndexMax = weatherData.uvIndexMax![index];
    }

    int? windDirection10MDominant;
    if ((weatherData.winddirection10MDominant?.length ?? 0) > index) {
      windDirection10MDominant = weatherData.winddirection10MDominant![index];
    }

    double? windSpeed10MMax;
    if ((weatherData.windspeed10MMax?.length ?? 0) > index) {
      windSpeed10MMax = weatherData.windspeed10MMax![index];
    }

    double? windGusts10MMax;
    if ((weatherData.windgusts10MMax?.length ?? 0) > index) {
      windGusts10MMax = weatherData.windgusts10MMax![index];
    }

    int? precipitationProbabilityMax;
    if ((weatherData.precipitationProbabilityMax?.length ?? 0) > index) {
      precipitationProbabilityMax =
          weatherData.precipitationProbabilityMax![index];
    }

    double? rainSum;
    if ((weatherData.rainSum?.length ?? 0) > index) {
      rainSum = weatherData.rainSum![index];
    }

    double? precipitationSum;
    if ((weatherData.precipitationSum?.length ?? 0) > index) {
      precipitationSum = weatherData.precipitationSum![index];
    }

    String? sunrise;
    if ((weatherData.sunrise?.length ?? 0) > index) {
      sunrise = weatherData.sunrise![index];
    }

    String? sunset;
    if ((weatherData.sunset?.length ?? 0) > index) {
      sunset = weatherData.sunset![index];
    }

    if (sunrise == null || sunset == null) {
      return Container();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: ListView(
        children: [
          _buildNowWidget(
            weatherData,
            index,
            startIndex,
            hourOfDay,
            sunrise,
            sunset,
          ),
          _buildHourlyList(context, weatherData, startIndex, sunrise, sunset),
          _buildSunsetSunriseWidget(sunrise, sunset),
          _buildHourlyDescContainer(weatherData, startIndex, hourOfDay),
          _buildDailyDescContainer(
            weatherData,
            temperature2MMin,
            temperature2MMax,
            apparentTemperatureMin,
            apparentTemperatureMax,
            uvIndexMax,
            windDirection10MDominant,
            windSpeed10MMax,
            windGusts10MMax,
            precipitationProbabilityMax,
            rainSum,
            precipitationSum,
          ),
        ],
      ),
    );
  }

  Widget _buildNowWidget(
    WeatherCard weatherData,
    int index,
    int startIndex,
    int hourOfDay,
    String sunrise,
    String sunset,
  ) {
    // Check if the hourly index is within bounds
    final hourlyIndex = startIndex + hourOfDay;
    final weatherCodeLength = weatherData.weathercode?.length ?? 0;
    final temperature2MLength = weatherData.temperature2M?.length ?? 0;
    final timeLength = weatherData.time?.length ?? 0;

    if (hourlyIndex >= weatherCodeLength ||
        hourlyIndex >= temperature2MLength ||
        hourlyIndex >= timeLength) {
      return Container();
    }

    final weatherCode = weatherData.weathercode?[hourlyIndex];
    final temperature = weatherData.temperature2M?[hourlyIndex];
    final time = weatherData.time?[hourlyIndex];
    final tempMax = weatherData.temperature2MMax?[index];
    final tempMin = weatherData.temperature2MMin?[index];
    
    // Use apparent temperature if available, otherwise fall back to temperature
    final apparentTempLength = weatherData.apparentTemperature?.length ?? 0;
    final apparentTemp = apparentTempLength > hourlyIndex
        ? weatherData.apparentTemperature![hourlyIndex]
        : null;
    final feels = apparentTemp ?? temperature;

    if (tempMax == null ||
        tempMin == null ||
        feels == null ||
        temperature == null ||
        time == null ||
        weatherCode == null) {
      return Container();
    }

    return Now(
      weather: weatherCode,
      degree: temperature,
      feels: feels,
      time: time,
      timeDay: sunrise,
      timeNight: sunset,
      tempMax: tempMax,
      tempMin: tempMin,
    );
  }

  Widget _buildHourlyList(
    BuildContext context,
    WeatherCard weatherData,
    int startIndex,
    String sunrise,
    String sunset,
  ) {
    // Calculate how many hours of data we have for this day
    final hourlyTimes = weatherData.time ?? [];
    int hourCount = 0;

    if (startIndex < hourlyTimes.length) {
      try {
        final startDay = DateTime.parse(hourlyTimes[startIndex]);

        // Count consecutive hours from the same day
        for (int i = startIndex; i < hourlyTimes.length; i++) {
          final currentTime = DateTime.parse(hourlyTimes[i]);
          if (currentTime.year == startDay.year &&
              currentTime.month == startDay.month &&
              currentTime.day == startDay.day) {
            hourCount++;
          } else {
            break;
          }
        }
      } catch (e) {
        hourCount = 0;
      }
    }

    print('Daily card info - Hour count for this day: $hourCount');

    if (hourCount == 0) {
      return Container();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: SizedBox(
          height: 135,
          child: ScrollablePositionedList.separated(
            separatorBuilder: (BuildContext context, int index) =>
                const VerticalDivider(width: 10, indent: 40, endIndent: 40),
            scrollDirection: Axis.horizontal,
            itemCount: hourCount,
            itemBuilder: (ctx, i) => _buildHourlyItem(
              context,
              weatherData,
              startIndex,
              i,
              sunrise,
              sunset,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyItem(
    BuildContext context,
    WeatherCard weatherData,
    int startIndex,
    int i,
    String sunrise,
    String sunset,
  ) {
    int hourlyIndex = startIndex + i;
    bool isSelected = i == hourOfDay;

    print(
      'Daily card info - Building hourly item $i, hourlyIndex: $hourlyIndex',
    );

    // Helper function to safely get array value
    T? safeGet<T>(List<T?>? array, int index) {
      if (array == null || index >= array.length) {
        print(
          'Daily card info - safeGet returning null for index $index (array length: ${array?.length ?? 0})',
        );
        return null;
      }
      return array[index];
    }

    // Safety check: ensure index is within bounds
    final hourlyDataLength = weatherData.time?.length ?? 0;
    if (hourlyIndex >= hourlyDataLength) {
      print(
        'Daily card info - hourlyIndex $hourlyIndex >= hourlyDataLength $hourlyDataLength, returning Container',
      );
      return Container();
    }

    final time = safeGet(weatherData.time, hourlyIndex);
    final weatherCode = safeGet(weatherData.weathercode, hourlyIndex);
    final temperature = safeGet(weatherData.temperature2M, hourlyIndex);

    print(
      'Daily card info - time: $time, weatherCode: $weatherCode, temperature: $temperature',
    );

    if (time == null || weatherCode == null || temperature == null) {
      print('Daily card info - One of the values is null, returning Container');
      return Container();
    }

    return GestureDetector(
      onTap: () => setState(() => hourOfDay = i),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? context.theme.colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Hourly(
          time: time,
          weather: weatherCode,
          degree: temperature,
          timeDay: sunrise,
          timeNight: sunset,
        ),
      ),
    );
  }

  Widget _buildSunsetSunriseWidget(String sunrise, String sunset) =>
      SunsetSunrise(timeSunrise: sunrise, timeSunset: sunset);

  Widget _buildHourlyDescContainer(
    WeatherCard weatherData,
    int startIndex,
    int hourOfDay,
  ) {
    final hourlyIndex = startIndex + hourOfDay;

    // Safety check: ensure index is within bounds for all arrays
    final hourlyDataLength = weatherData.time?.length ?? 0;
    if (hourlyIndex >= hourlyDataLength) {
      return Container();
    }

    // Helper function to safely get array value
    T? safeGet<T>(List<T?>? array, int index) {
      if (array == null || index >= array.length) return null;
      return array[index];
    }

    return DescContainer(
      humidity: safeGet(weatherData.relativehumidity2M, hourlyIndex),
      wind: safeGet(weatherData.windspeed10M, hourlyIndex),
      visibility: safeGet(weatherData.visibility, hourlyIndex),
      feels: safeGet(weatherData.apparentTemperature, hourlyIndex),
      evaporation: safeGet(weatherData.evapotranspiration, hourlyIndex),
      precipitation: safeGet(weatherData.precipitation, hourlyIndex),
      direction: safeGet(weatherData.winddirection10M, hourlyIndex),
      pressure: safeGet(weatherData.surfacePressure, hourlyIndex),
      rain: safeGet(weatherData.rain, hourlyIndex),
      cloudcover: safeGet(weatherData.cloudcover, hourlyIndex),
      windgusts: safeGet(weatherData.windgusts10M, hourlyIndex),
      uvIndex: safeGet(weatherData.uvIndex, hourlyIndex),
      dewpoint2M: safeGet(weatherData.dewpoint2M, hourlyIndex),
      precipitationProbability: safeGet(
        weatherData.precipitationProbability,
        hourlyIndex,
      ),
      shortwaveRadiation: safeGet(weatherData.shortwaveRadiation, hourlyIndex),
      initiallyExpanded: true,
      title: 'hourlyVariables'.tr,
    );
  }

  Widget _buildDailyDescContainer(
    WeatherCard weatherData,
    double? temperature2MMin,
    double? temperature2MMax,
    double? apparentTemperatureMin,
    double? apparentTemperatureMax,
    double? uvIndexMax,
    int? windDirection10MDominant,
    double? windSpeed10MMax,
    double? windGusts10MMax,
    int? precipitationProbabilityMax,
    double? rainSum,
    double? precipitationSum,
  ) => DescContainer(
    apparentTemperatureMin: apparentTemperatureMin,
    apparentTemperatureMax: apparentTemperatureMax,
    uvIndexMax: uvIndexMax,
    windDirection10MDominant: windDirection10MDominant,
    windSpeed10MMax: windSpeed10MMax,
    windGusts10MMax: windGusts10MMax,
    precipitationProbabilityMax: precipitationProbabilityMax,
    rainSum: rainSum,
    precipitationSum: precipitationSum,
    initiallyExpanded: true,
    title: 'dailyVariables'.tr,
  );
}
