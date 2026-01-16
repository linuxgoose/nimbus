import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:isar_community/isar.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;
import 'package:path_provider/path_provider.dart';
import 'package:nimbus/app/api/api.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/utils/notification.dart';
import 'package:nimbus/app/utils/show_snack_bar.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_data.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_weather.dart';
import 'package:nimbus/main.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/standalone.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';
import 'package:intl/intl.dart';

class WeatherController extends GetxController {
  final isLoading = true.obs;
  final _district = ''.obs;
  final _city = ''.obs;
  final _country = ''.obs;
  final _latitude = 0.0.obs;
  final _longitude = 0.0.obs;

  String get district => _district.value;
  String get city => _city.value;
  String get country => _country.value;
  double get latitude => _latitude.value;
  double get longitude => _longitude.value;

  final _mainWeather = MainWeatherCache().obs;
  final _location = LocationCache().obs;
  final _weatherCard = WeatherCard().obs;

  final weatherCards = <WeatherCard>[].obs;

  MainWeatherCache get mainWeather => _mainWeather.value;
  LocationCache get location => _location.value;
  WeatherCard get weatherCard => _weatherCard.value;

  final hourOfDay = 0.obs;
  final dayOfNow = 0.obs;
  final itemScrollController = ItemScrollController();
  final cacheExpiry = DateTime.now().subtract(const Duration(hours: 12));

  @override
  void onInit() {
    weatherCards.assignAll(
      isar.weatherCards.where().sortByIndex().findAllSync(),
    );
    super.onInit();
  }

  Future<Position> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> setLocation() async {
    if (settings.location) {
      await getCurrentLocation();
    } else {
      final locationCity = isar.locationCaches.where().findFirstSync();
      if (locationCity != null) {
        await getLocation(
          locationCity.lat!,
          locationCity.lon!,
          locationCity.district!,
          locationCity.city!,
        );
      }
    }
  }

  Future<void> getCurrentLocation() async {
    if (!(await isOnline.value)) {
      showSnackBar(content: 'no_inter'.tr);
      await readCache();
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      showSnackBar(
        content: 'no_location'.tr,
        onPressed: () => Geolocator.openLocationSettings(),
      );
      await readCache();
      return;
    }

    if (isar.mainWeatherCaches.where().findAllSync().isNotEmpty) {
      await readCache();
      return;
    }

    final position = await _determinePosition();
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final place = placemarks[0];

    _latitude.value = position.latitude;
    _longitude.value = position.longitude;
    _district.value = place.administrativeArea ?? '';
    _city.value = place.locality ?? '';
    _country.value = place.country ?? '';

    _mainWeather.value = await WeatherAPI().getWeatherData(
      _latitude.value,
      _longitude.value,
    );

    notificationCheck();
    await writeCache();
    await readCache();
  }

  Future<Map<String, dynamic>> getCurrentLocationSearch() async {
    if (!(await isOnline.value)) {
      showSnackBar(content: 'no_inter'.tr);
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      showSnackBar(
        content: 'no_location'.tr,
        onPressed: () => Geolocator.openLocationSettings(),
      );
    }

    final position = await _determinePosition();
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final place = placemarks[0];

    return {
      'lat': position.latitude,
      'lon': position.longitude,
      'city': place.administrativeArea ?? '',
      'district': place.locality ?? '',
      'country': place.country ?? '',
    };
  }

  Future<void> getLocation(
    double latitude,
    double longitude,
    String district,
    String locality,
  ) async {
    if (!(await isOnline.value)) {
      showSnackBar(content: 'no_inter'.tr);
      await readCache();
      return;
    }

    if (isar.mainWeatherCaches.where().findAllSync().isNotEmpty) {
      await readCache();
      return;
    }

    _latitude.value = latitude;
    _longitude.value = longitude;
    _district.value = district;
    _city.value = locality;

    _mainWeather.value = await WeatherAPI().getWeatherData(
      _latitude.value,
      _longitude.value,
    );

    notificationCheck();
    await writeCache();
    await readCache();
  }

  Future<void> readCache() async {
    MainWeatherCache? mainWeatherCache = isar.mainWeatherCaches
        .where()
        .findFirstSync();
    LocationCache? locationCache = isar.locationCaches.where().findFirstSync();

    if (mainWeatherCache == null || locationCache == null) {
      isLoading.value = false;
      return;
    }

    _mainWeather.value = mainWeatherCache;
    _location.value = locationCache;

    hourOfDay.value = getTime(
      _mainWeather.value.time,
      _mainWeather.value.timezone,
    );
    dayOfNow.value = getDay(
      _mainWeather.value.timeDaily,
      _mainWeather.value.timezone,
    );

    if (Platform.isAndroid) {
      Workmanager().registerPeriodicTask(
        'widgetUpdate',
        'widgetBackgroundUpdate',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    }

    await updateWidget();

    isLoading.value = false;
    Future.delayed(const Duration(milliseconds: 30), scrollToCurrentHour);
  }

  void scrollToCurrentHour() {
    if (itemScrollController.isAttached) {
      itemScrollController.scrollTo(
        index: hourOfDay.value,
        duration: const Duration(seconds: 2),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 100), scrollToCurrentHour);
    }
  }

  Future<void> writeCache() async {
    final locationCaches = LocationCache(
      lat: _latitude.value,
      lon: _longitude.value,
      city: _city.value,
      district: _district.value,
      country: _country.value,
    );

    isar.writeTxnSync(() {
      if (isar.mainWeatherCaches.where().findAllSync().isEmpty) {
        isar.mainWeatherCaches.putSync(_mainWeather.value);
      }
      if (isar.locationCaches.where().findAllSync().isEmpty) {
        isar.locationCaches.putSync(locationCaches);
      }
    });
  }

  Future<void> deleteCache() async {
    if (!(await isOnline.value)) {
      return;
    }

    isar.writeTxnSync(
      () => isar.mainWeatherCaches
          .filter()
          .timestampLessThan(cacheExpiry)
          .deleteAllSync(),
    );
    if (isar.mainWeatherCaches.where().findAllSync().isEmpty) {
      await flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  Future<void> deleteAll(bool changeCity) async {
    if (!(await isOnline.value)) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    await flutterLocalNotificationsPlugin.cancelAll();

    isar.writeTxnSync(() {
      if (!settings.location) {
        isar.mainWeatherCaches.where().deleteAllSync();
      }
      if (settings.location && serviceEnabled || changeCity) {
        isar.mainWeatherCaches.where().deleteAllSync();
        isar.locationCaches.where().deleteAllSync();
      }
    });
  }

  Future<void> addCardWeather(
    double latitude,
    double longitude,
    String city,
    String district,
  ) async {
    if (!(await isOnline.value)) {
      showSnackBar(content: 'no_inter'.tr);
      return;
    }

    final tz = tzmap.latLngToTimezoneString(latitude, longitude);
    _weatherCard.value = await WeatherAPI().getWeatherCard(
      latitude,
      longitude,
      city,
      district,
      tz,
    );
    isar.writeTxnSync(() {
      weatherCards.add(_weatherCard.value);
      isar.weatherCards.putSync(_weatherCard.value);
    });
  }

  Future<void> updateCardLocation(
    WeatherCard card,
    double latitude,
    double longitude,
    String city,
    String district,
  ) async {
    if (!(await isOnline.value)) {
      showSnackBar(content: 'no_inter'.tr);
      return;
    }

    final tz = tzmap.latLngToTimezoneString(latitude, longitude);
    final updatedCard = await WeatherAPI().getWeatherCard(
      latitude,
      longitude,
      city,
      district,
      tz,
    );

    isar.writeTxnSync(() {
      card.lat = latitude;
      card.lon = longitude;
      card.city = city;
      card.district = district;
      card.timezone = tz;

      _updateWeatherCard(card, updatedCard);
      isar.weatherCards.putSync(card);
    });

    weatherCards.refresh();
  }

  Future<void> updateCacheCard(bool refresh) async {
    final weatherCard = refresh
        ? isar.weatherCards.where().sortByIndex().findAllSync()
        : isar.weatherCards
              .filter()
              .timestampLessThan(cacheExpiry)
              .sortByIndex()
              .findAllSync();

    if (!(await isOnline.value) || weatherCard.isEmpty) {
      return;
    }

    for (var oldCard in weatherCard) {
      final updatedCard = await WeatherAPI().getWeatherCard(
        oldCard.lat!,
        oldCard.lon!,
        oldCard.city!,
        oldCard.district!,
        oldCard.timezone!,
      );
      isar.writeTxnSync(() {
        _updateWeatherCard(oldCard, updatedCard);
        weatherCards.refresh();
      });
    }
  }

  void _updateWeatherCard(WeatherCard oldCard, WeatherCard updatedCard) {
    oldCard
      ..time = updatedCard.time
      ..weathercode = updatedCard.weathercode
      ..temperature2M = updatedCard.temperature2M
      ..apparentTemperature = updatedCard.apparentTemperature
      ..relativehumidity2M = updatedCard.relativehumidity2M
      ..precipitation = updatedCard.precipitation
      ..rain = updatedCard.rain
      ..surfacePressure = updatedCard.surfacePressure
      ..visibility = updatedCard.visibility
      ..evapotranspiration = updatedCard.evapotranspiration
      ..windspeed10M = updatedCard.windspeed10M
      ..winddirection10M = updatedCard.winddirection10M
      ..windgusts10M = updatedCard.windgusts10M
      ..cloudcover = updatedCard.cloudcover
      ..uvIndex = updatedCard.uvIndex
      ..dewpoint2M = updatedCard.dewpoint2M
      ..precipitationProbability = updatedCard.precipitationProbability
      ..shortwaveRadiation = updatedCard.shortwaveRadiation
      ..timeDaily = updatedCard.timeDaily
      ..weathercodeDaily = updatedCard.weathercodeDaily
      ..temperature2MMax = updatedCard.temperature2MMax
      ..temperature2MMin = updatedCard.temperature2MMin
      ..apparentTemperatureMax = updatedCard.apparentTemperatureMax
      ..apparentTemperatureMin = updatedCard.apparentTemperatureMin
      ..sunrise = updatedCard.sunrise
      ..sunset = updatedCard.sunset
      ..precipitationSum = updatedCard.precipitationSum
      ..precipitationProbabilityMax = updatedCard.precipitationProbabilityMax
      ..windspeed10MMax = updatedCard.windspeed10MMax
      ..windgusts10MMax = updatedCard.windgusts10MMax
      ..uvIndexMax = updatedCard.uvIndexMax
      ..rainSum = updatedCard.rainSum
      ..winddirection10MDominant = updatedCard.winddirection10MDominant
      ..timestamp = DateTime.now();

    isar.weatherCards.putSync(oldCard);
  }

  Future<void> updateCard(WeatherCard weatherCard) async {
    if (!(await isOnline.value)) {
      return;
    }

    final updatedCard = await WeatherAPI().getWeatherCard(
      weatherCard.lat!,
      weatherCard.lon!,
      weatherCard.city!,
      weatherCard.district!,
      weatherCard.timezone!,
    );

    isar.writeTxnSync(() => _updateWeatherCard(weatherCard, updatedCard));
  }

  Future<void> deleteCardWeather(WeatherCard weatherCard) async =>
      await isar.writeTxnSync(() {
        weatherCards.remove(weatherCard);
        isar.weatherCards.deleteSync(weatherCard.id);
      });

  int getTime(List<String?>? time, String? timezone) {
    if (time == null || timezone == null || time.isEmpty) return 0;
    try {
      return time.indexWhere((t) {
        if (t == null) return false;
        final dateTime = DateTime.parse(t);
        final location = tz.getLocation(timezone);
        final now = tz.TZDateTime.now(location);
        return now.hour == dateTime.hour && now.day == dateTime.day;
      });
    } catch (e) {
      return 0;
    }
  }

  int getDay(List<DateTime?>? time, String? timezone) {
    if (time == null || timezone == null || time.isEmpty) return 0;
    try {
      final location = tz.getLocation(timezone);
      final nowDay = tz.TZDateTime.now(location).day;
      return time.indexWhere((t) => t?.day == nowDay);
    } catch (e) {
      return 0;
    }
  }

  TimeOfDay parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    try {
      if (timeStr.contains(' ')) {
        final isPM = timeStr.endsWith('PM');
        final timeParts = timeStr.split(' ')[0].split(':');
        int hour = int.parse(timeParts[0]);
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        final minute = int.parse(timeParts[1]);
        return TimeOfDay(hour: hour % 24, minute: minute);
      } else {
        final parts = timeStr.split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String timeTo24h(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String formatTime(String? timeStr) {
    final time = parseTime(timeStr);
    final dateTime = DateTime(0, 0, 0, time.hour, time.minute);
    if (settings.timeformat == '12') {
      return DateFormat.jm(locale.languageCode).format(dateTime);
    } else {
      return DateFormat.Hm(locale.languageCode).format(dateTime);
    }
  }

  Future<String> getLocalImagePath(String icon) async {
    final directory = await getApplicationSupportDirectory();
    final imagePath = '${directory.path}/$icon';

    if (!await File(imagePath).exists()) {
      final data = await rootBundle.load('assets/images/$icon');
      final bytes = data.buffer.asUint8List();
      await File(imagePath).writeAsBytes(bytes);
    }

    return imagePath;
  }

  void notification(MainWeatherCache mainWeatherCache) async {
    final now = DateTime.now();
    final startHour = parseTime(timeStart).hour;
    final endHour = parseTime(timeEnd).hour;

    final timeList = mainWeatherCache.time ?? [];
    for (var i = 0; i < timeList.length; i += timeRange) {
      final timeStr = timeList[i];
      final notificationTime = DateTime.parse(timeStr);

      if (notificationTime.isAfter(now) &&
          notificationTime.hour >= startHour &&
          notificationTime.hour <= endHour) {
        final dailyTime = mainWeatherCache.timeDaily ?? [];
        for (var j = 0; j < dailyTime.length; j++) {
          if (dailyTime[j].day == notificationTime.day) {
            NotificationShow().showNotification(
              UniqueKey().hashCode,
              '$city: ${mainWeatherCache.temperature2M?[i] ?? 0}°',
              '${StatusWeather().getText(mainWeatherCache.weathercode?[i] ?? 0)} · ${StatusData().getTimeFormat(timeStr)}',
              notificationTime,
              StatusWeather().getImageNotification(
                mainWeatherCache.weathercode?[i] ?? 0,
                timeStr,
                mainWeatherCache.sunrise?[j] ?? "",
                mainWeatherCache.sunset?[j] ?? "",
              ),
            );
          }
        }
      }
    }
  }

  void notificationCheck() async {
    if (settings.notifications) {
      final pendingNotificationRequests = await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      if (pendingNotificationRequests.isEmpty) {
        notification(_mainWeather.value);
      }
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final element = weatherCards.removeAt(oldIndex);
    weatherCards.insert(newIndex, element);

    for (int i = 0; i < weatherCards.length; i++) {
      final item = weatherCards[i];
      item.index = i;
      isar.writeTxnSync(() => isar.weatherCards.putSync(item));
    }
  }

  Future<bool> updateWidgetBackgroundColor(String color) async {
    settings.widgetBackgroundColor = color;
    isar.writeTxnSync(() => isar.settings.putSync(settings));

    final results = await Future.wait<bool?>([
      HomeWidget.saveWidgetData('background_color', color),
      HomeWidget.updateWidget(androidName: 'CurrentWidget'),
      HomeWidget.updateWidget(androidName: 'OreoWidget'),
      HomeWidget.updateWidget(androidName: 'HourlyWidget'),
      HomeWidget.updateWidget(androidName: 'DailyWidget'),
    ]);
    return !results.contains(false);
  }

  Future<bool> updateWidgetTextColor(String color) async {
    settings.widgetTextColor = color;
    isar.writeTxnSync(() => isar.settings.putSync(settings));

    final results = await Future.wait<bool?>([
      HomeWidget.saveWidgetData('text_color', color),
      HomeWidget.updateWidget(androidName: 'CurrentWidget'),
      HomeWidget.updateWidget(androidName: 'OreoWidget'),
      HomeWidget.updateWidget(androidName: 'HourlyWidget'),
      HomeWidget.updateWidget(androidName: 'DailyWidget'),
    ]);
    return !results.contains(false);
  }

  Future<bool> updateWidget() async {
    try {
      tz.initializeTimeZones();

      final isarWidget =
          Isar.getInstance() ??
          await Isar.open([
            SettingsSchema,
            MainWeatherCacheSchema,
            LocationCacheSchema,
            WeatherCardSchema,
          ], directory: (await getApplicationSupportDirectory()).path);

      final mainWeatherCache = isarWidget.mainWeatherCaches
          .where()
          .findFirstSync();
      final locationCache = isarWidget.locationCaches.where().findFirstSync();
      final speedUnit = settings.wind;

      if (mainWeatherCache == null) return false;

      final hour = getTime(mainWeatherCache.time, mainWeatherCache.timezone);
      final day = getDay(mainWeatherCache.timeDaily, mainWeatherCache.timezone);

      await HomeWidget.setAppGroupId(appGroupId);

      // Save Location Name
      final String cityName = locationCache?.city ?? "Unknown";
      final String districtName = locationCache?.district ?? "";
      final String displayName = districtName.isNotEmpty
          ? "$cityName, $districtName"
          : cityName;

      await HomeWidget.saveWidgetData('location_name', displayName);

      // --- Current Weather Data ---
      final degree = '${(mainWeatherCache.temperature2M?[hour] ?? 0).round()}°';
      final description = StatusWeather().getText(
        mainWeatherCache.weathercode?[hour] ?? 0,
      );
      final windSpeed =
          '${mainWeatherCache.windspeed10M?[hour]?.round() ?? 0} $speedUnit';
      final humidity = '${mainWeatherCache.relativehumidity2M?[hour] ?? 0}%';
      final visibilityVal = ((mainWeatherCache.visibility?[hour] ?? 0) / 1000)
          .round();
      final visibility = '$visibilityVal km';

      await HomeWidget.saveWidgetData('weather_degree', degree);
      await HomeWidget.saveWidgetData('weather_description', description);
      await HomeWidget.saveWidgetData('weather_wind', windSpeed);
      await HomeWidget.saveWidgetData('weather_humidity', humidity);
      await HomeWidget.saveWidgetData('weather_visibility', visibility);

      // --- Weather Icon ---
      try {
        final imagePath = await getLocalImagePath(
          StatusWeather().getImageNotification(
            mainWeatherCache.weathercode?[hour] ?? 0,
            mainWeatherCache.time?[hour] ?? "",
            mainWeatherCache.sunrise?[day] ?? "",
            mainWeatherCache.sunset?[day] ?? "",
          ),
        );
        await HomeWidget.saveWidgetData('weather_icon', imagePath);
      } catch (_) {}

      // --- Hourly & Daily Forecasting ---
      await _updateHourlyWidget(mainWeatherCache, hour, day);
      await _updateDailyWidget(mainWeatherCache, day);

      final bool updated = (await Future.wait<bool?>([
        HomeWidget.updateWidget(androidName: 'CurrentWidget'),
        HomeWidget.updateWidget(androidName: 'OreoWidget'),
        HomeWidget.updateWidget(androidName: 'HourlyWidget'),
        HomeWidget.updateWidget(androidName: 'DailyWidget'),
      ])).any((result) => result == true);

      return updated;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateHourlyWidget(
    MainWeatherCache mainWeatherCache,
    int currentHour,
    int currentDay,
  ) async {
    try {
      final speedUnit = settings.wind;
      final timeList = mainWeatherCache.time ?? [];
      for (int i = 0; i < 6; i++) {
        final hourIndex = currentHour + i;
        if (hourIndex >= timeList.length) break;

        final time = timeList[hourIndex];
        final weathercode = mainWeatherCache.weathercode?[hourIndex];
        final temp = mainWeatherCache.temperature2M?[hourIndex];
        final wind = mainWeatherCache.windspeed10M?[hourIndex];

        final timeFormat = DateFormat.Hm(
          locale.languageCode,
        ).format(DateTime.parse(time));

        final tempStr = '${temp?.round() ?? 0}°';
        final windStr = '${wind?.round() ?? 0} $speedUnit';

        await HomeWidget.saveWidgetData('hourly_time_$i', timeFormat);
        await HomeWidget.saveWidgetData('hourly_temp_$i', tempStr);
        await HomeWidget.saveWidgetData('hourly_wind_$i', windStr);

        try {
          int dayIdx = currentDay;
          if (DateTime.parse(time).day != DateTime.now().day) {
            if (currentDay + 1 < (mainWeatherCache.sunrise?.length ?? 0)) {
              dayIdx = currentDay + 1;
            }
          }

          final imagePath = await getLocalImagePath(
            StatusWeather().getImageNotification(
              weathercode ?? 0,
              time,
              mainWeatherCache.sunrise?[dayIdx] ?? "",
              mainWeatherCache.sunset?[dayIdx] ?? "",
            ),
          );
          await HomeWidget.saveWidgetData('hourly_icon_$i', imagePath);
        } catch (e) {
          debugPrint("Widget Hourly Icon Error at index $i: $e");
        }
      }
      await HomeWidget.updateWidget(androidName: 'HourlyWidget');
    } catch (e) {
      debugPrint("Widget Hourly Loop Error: $e");
    }
  }

  Future<void> _updateDailyWidget(
    MainWeatherCache mainWeatherCache,
    int currentDay,
  ) async {
    try {
      final dailyTime = mainWeatherCache.timeDaily ?? [];
      for (int i = 0; i < 6 && (currentDay + i) < dailyTime.length; i++) {
        final dayIndex = currentDay + i;
        final date = dailyTime[dayIndex];
        final weathercode = mainWeatherCache.weathercodeDaily?[dayIndex];
        final tempMax = mainWeatherCache.temperature2MMax?[dayIndex];
        final tempMin = mainWeatherCache.temperature2MMin?[dayIndex];
        final windSpeed = mainWeatherCache.windspeed10MMax?[dayIndex];
        final precipProb =
            mainWeatherCache.precipitationProbabilityMax?[dayIndex];

        final dateFormat = DateFormat.MMMd(locale.languageCode).format(date);

        await HomeWidget.saveWidgetData('daily_date_$i', dateFormat);
        await HomeWidget.saveWidgetData(
          'daily_max_$i',
          '${tempMax?.round() ?? 0}°',
        );
        await HomeWidget.saveWidgetData(
          'daily_min_$i',
          '${tempMin?.round() ?? 0}°',
        );

        // Save wind speed
        await HomeWidget.saveWidgetData(
          'daily_wind_$i',
          '${windSpeed?.round() ?? 0} ${settings.wind}',
        );

        // Save precipitation probability
        await HomeWidget.saveWidgetData(
          'daily_precip_$i',
          '${precipProb ?? 0}%',
        );

        try {
          final sunrise = mainWeatherCache.sunrise?[dayIndex];
          final sunset = mainWeatherCache.sunset?[dayIndex];
          final imagePath = await getLocalImagePath(
            StatusWeather().getImageNotification(
              weathercode ?? 0,
              '${DateFormat('yyyy-MM-dd').format(date)}T12:00',
              sunrise ?? "",
              sunset ?? "",
            ),
          );
          await HomeWidget.saveWidgetData('daily_icon_$i', imagePath);
        } catch (_) {}
      }
      await HomeWidget.updateWidget(androidName: 'DailyWidget');
    } catch (e) {
      debugPrint("Widget Daily Loop Error: $e");
    }
  }

  void urlLauncher(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
