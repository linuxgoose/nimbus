import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hsvcolor_picker/flutter_hsvcolor_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/ui/alert_history/view/alert_history_page.dart';
import 'package:nimbus/app/ui/settings/widgets/setting_card.dart';
import 'package:nimbus/main.dart';
import 'package:nimbus/theme/theme_controller.dart';
import 'package:nimbus/app/utils/color_converter.dart';
import 'package:nimbus/app/utils/show_snack_bar.dart';
import 'package:restart_app/restart_app.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final themeController = Get.put(ThemeController());
  final weatherController = Get.put(WeatherController());
  String? appVersion;
  String? colorBackground;
  String? colorText;

  @override
  void initState() {
    super.initState();
    _infoVersion();
  }

  Future<void> _infoVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() => appVersion = packageInfo.version);
  }

  void _updateLanguage(Locale locale) {
    settings.language = '$locale';
    isar.writeTxnSync(() => isar.settings.putSync(settings));
    Get.updateLocale(locale);
    Get.back();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAppearanceCard(context),
        _buildFunctionsCard(context),
        _buildTidesCard(context),
        _buildWeatherAlertsCard(context),
        _buildAqiCard(context),
        _buildDataCard(context),
        _buildWidgetCard(context),
        _buildMapCard(context),
        _buildLanguageCard(context),
        _buildLicenseCard(context),
        _buildVersionCard(context),
        _buildGitHubCard(context),
        _buildSupportCard(context),
        _buildOpenMeteoText(context),
      ],
    ),
  );

  Widget _buildAppearanceCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.paintRoller),
    text: 'appearance'.tr,
    onPressed: () => _showAppearanceBottomSheet(context),
  );

  void _showAppearanceBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAppearanceTitle(context),
              _buildThemeSettingCard(context, setState),
              _buildAmoledThemeSettingCard(context, setState),
              _buildMaterialColorSettingCard(context, setState),
              _buildLargeElementSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildAppearanceTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'appearance'.tr,
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
  );

  Widget _buildThemeSettingCard(BuildContext context, StateSetter setState) =>
      SettingCard(
        elevation: 4,
        icon: const Icon(LucideIcons.moon),
        text: 'theme'.tr,
        dropdown: true,
        dropdownName: settings.theme?.tr,
        dropdownList: <String>['system'.tr, 'dark'.tr, 'light'.tr],
        dropdownChange: (String? newValue) =>
            _updateTheme(newValue, context, setState),
      );

  void _updateTheme(
    String? newValue,
    BuildContext context,
    StateSetter setState,
  ) {
    ThemeMode themeMode = newValue?.tr == 'system'.tr
        ? ThemeMode.system
        : newValue?.tr == 'dark'.tr
        ? ThemeMode.dark
        : ThemeMode.light;
    String theme = newValue?.tr == 'system'.tr
        ? 'system'
        : newValue?.tr == 'dark'.tr
        ? 'dark'
        : 'light';
    themeController.saveTheme(theme);
    themeController.changeThemeMode(themeMode);
  }

  Widget _buildAmoledThemeSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.tabletSmartphone),
    text: 'amoledTheme'.tr,
    switcher: true,
    value: settings.amoledTheme,
    onChange: (value) {
      themeController.saveOledTheme(value);
      MyApp.updateAppState(context, newAmoledTheme: value);
    },
  );

  Widget _buildMaterialColorSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.blend),
    text: 'materialColor'.tr,
    switcher: true,
    value: settings.materialColor,
    onChange: (value) {
      themeController.saveMaterialTheme(value);
      MyApp.updateAppState(context, newMaterialColor: value);
    },
  );

  Widget _buildLargeElementSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.expand),
    text: 'largeElement'.tr,
    switcher: true,
    value: settings.largeElement,
    onChange: (value) {
      settings.largeElement = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      MyApp.updateAppState(context, newLargeElement: value);
      setState(() {});
    },
  );

  Widget _buildFunctionsCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.chartSpline),
    text: 'functions'.tr,
    onPressed: () => _showFunctionsBottomSheet(context),
  );

  Widget _buildTidesCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.waves),
    text: 'Tides',
    onPressed: () => _showTidesBottomSheet(context),
  );

  void _showTidesBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTidesTitle(context),
              _buildHideTidesSettingCard(context, setState),
              _buildUseDummyTidesSettingCard(context, setState),
              _buildTidesApiKeySettingCard(context, setState),
              _buildCheckTidesCacheSettingCard(context, setState),
              _buildClearTidesCacheSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildTidesTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text('Tides', style: context.textTheme.headlineSmall),
  );

  Widget _buildWeatherAlertsCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.triangleAlert),
    text: 'Weather Alerts',
    onPressed: () => _showWeatherAlertsBottomSheet(context),
  );

  Widget _buildAqiCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.wind),
    text: 'Air Quality Index',
    onPressed: () => _showAqiBottomSheet(context),
  );

  void _showAqiBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAqiTitle(context),
              _buildHideAqiSettingCard(context, setState),
              _buildAqiIndexSettingCard(context, setState),
              _buildCheckAqiCacheSettingCard(context, setState),
              _buildClearAqiCacheSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildAqiTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text('Air Quality Index', style: context.textTheme.headlineSmall),
  );

  Widget _buildHideAqiSettingCard(BuildContext context, StateSetter setState) =>
      SettingCard(
        elevation: 4,
        icon: const Icon(LucideIcons.eyeOff),
        text: 'Hide Air Quality Index',
        switcher: true,
        value: settings.hideAqi,
        onChange: (value) {
          settings.hideAqi = value;
          isar.writeTxnSync(() => isar.settings.putSync(settings));
          setState(() {});
        },
      );

  void _showWeatherAlertsBottomSheet(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, setState) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWeatherAlertsTitle(context),
                  _buildDummyAlertsSettingCard(context, setState),
                  _buildAlertSeveritySettingCard(context, setState),
                  _buildShowAlertsOnMainPageSettingCard(context, setState),
                  _buildShowAlertsOnMapSettingCard(context, setState),
                  _buildViewAlertHistoryCard(context),
                  const Gap(10),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildWeatherAlertsTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text('Weather Alerts', style: context.textTheme.headlineSmall),
  );

  void _showFunctionsBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFunctionsTitle(context),
              _buildLocationSettingCard(context, setState),
              _buildNotificationsSettingCard(context, setState),
              _buildTimeRangeSettingCard(context, setState),
              _buildTimeStartSettingCard(context, setState),
              _buildTimeEndSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildFunctionsTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'functions'.tr,
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
  );

  Widget _buildLocationSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.mapPin),
    text: 'location'.tr,
    switcher: true,
    value: settings.location,
    onChange: (value) async {
      if (value) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (!context.mounted) return;
          await _showLocationDialog(context);
          return;
        }
        weatherController.getCurrentLocation();
      }
      isar.writeTxnSync(() {
        settings.location = value;
        isar.settings.putSync(settings);
      });
      setState(() {});
    },
  );

  Future<void> _showLocationDialog(BuildContext context) async =>
      await showAdaptiveDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog.adaptive(
          title: Text('location'.tr, style: context.textTheme.titleLarge),
          content: Text('no_location'.tr, style: context.textTheme.titleMedium),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text(
                'cancel'.tr,
                style: context.textTheme.titleMedium?.copyWith(
                  color: Colors.blueAccent,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Geolocator.openLocationSettings();
                Get.back(result: true);
              },
              child: Text(
                'settings'.tr,
                style: context.textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildNotificationsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.bellDot),
    text: 'notifications'.tr,
    switcher: true,
    value: settings.notifications,
    onChange: (value) async {
      final resultExact = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
      final result = Platform.isIOS
          ? await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions()
          : await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission();
      if (result != null && resultExact != null) {
        isar.writeTxnSync(() {
          settings.notifications = value;
          isar.settings.putSync(settings);
        });
        if (value) {
          weatherController.notification(weatherController.mainWeather);
        } else {
          flutterLocalNotificationsPlugin.cancelAll();
        }
        setState(() {});
      }
    },
  );

  Widget _buildHideTidesSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.waves),
    text: 'hideTides'.tr,
    switcher: true,
    value: settings.hideTides,
    onChange: (value) {
      settings.hideTides = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
      Future.delayed(
        const Duration(milliseconds: 500),
        () => Restart.restartApp(),
      );
    },
  );

  Widget _buildUseDummyTidesSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.testTube),
    text: 'Use Dummy Tide Data',
    switcher: true,
    value: settings.useDummyTides,
    onChange: (value) {
      settings.useDummyTides = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildTidesApiKeySettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.key),
    text: 'Stormglass API Key',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: settings.tidesApiKey?.isNotEmpty == true
          ? '${settings.tidesApiKey!.substring(0, 8)}...'
          : 'Not set',
    ),
    onPressed: () => _showTidesApiKeyDialog(context, setState),
  );

  void _showTidesApiKeyDialog(BuildContext context, StateSetter setState) {
    final controller = TextEditingController(text: settings.tidesApiKey ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stormglass API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get your free API key (10 requests/day) from:',
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              'https://stormglass.io/',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                prefixIcon: Icon(LucideIcons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settings.tidesApiKey = controller.text.trim();
              if (settings.tidesApiKey!.isEmpty) {
                settings.tidesApiKey = null;
              }
              isar.writeTxnSync(() => isar.settings.putSync(settings));
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckTidesCacheSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.database),
    text: 'Check Tide Cache',
    onPressed: () {
      final cacheCount = isar.tideCaches.countSync();
      final caches = isar.tideCaches
          .getAllSync([])
          .whereType<TideCache>()
          .toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tide Cache Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total cached entries: $cacheCount'),
              const SizedBox(height: 16),
              if (caches.isNotEmpty) ...[
                const Text(
                  'Cached locations:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...caches.map(
                  (cache) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${cache.locationKey}\n  Cached: ${cache.cachedAt}\n  Expires: ${cache.expiresAt}',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildClearTidesCacheSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.trash2),
    text: 'Clear Tide Cache',
    onPressed: () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Tide Cache'),
          content: const Text(
            'Are you sure you want to clear all cached tide data?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                isar.writeTxnSync(() {
                  isar.tideCaches.clearSync();
                });
                Navigator.pop(context);
                // ignore: void_checks
                showSnackBar(content: 'Cleared tide cache entries');
                setState(() {});
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildCheckAqiCacheSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.database),
    text: 'Check AQI Cache',
    onPressed: () {
      final cacheCount = isar.aqiCaches.countSync();
      final caches = isar.aqiCaches
          .getAllSync([])
          .whereType<AqiCache>()
          .toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AQI Cache Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total cached entries: $cacheCount'),
              const SizedBox(height: 16),
              if (caches.isNotEmpty) ...[
                const Text(
                  'Cached locations:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...caches.map(
                  (cache) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${cache.locationKey}\n  Cached: ${cache.cachedAt}\n  Expires: ${cache.expiresAt}',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildClearAqiCacheSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.trash2),
    text: 'Clear AQI Cache',
    onPressed: () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear AQI Cache'),
          content: const Text(
            'Are you sure you want to clear all cached AQI data?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                isar.writeTxnSync(() {
                  isar.aqiCaches.clearSync();
                });
                Navigator.pop(context);
                // ignore: void_checks
                showSnackBar(content: 'Cleared AQI cache entries');
                setState(() {});
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildTimeRangeSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.bellRing),
    text: 'timeRange'.tr,
    dropdown: true,
    dropdownName: '$timeRange',
    dropdownList: const <String>['1', '2', '3', '4', '5'],
    dropdownChange: (String? newValue) {
      isar.writeTxnSync(() {
        settings.timeRange = int.parse(newValue!);
        isar.settings.putSync(settings);
      });
      MyApp.updateAppState(context, newTimeRange: int.parse(newValue!));
      if (settings.notifications) {
        flutterLocalNotificationsPlugin.cancelAll();
        weatherController.notification(weatherController.mainWeather);
      }
    },
  );

  Widget _buildTimeStartSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.timer),
    text: 'timeStart'.tr,
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(info: weatherController.formatTime(timeStart)),
    onPressed: () async {
      final TimeOfDay? timeStartPicker = await showTimePicker(
        context: context,
        initialTime: weatherController.parseTime(timeStart),
        builder: (context, child) {
          final Widget mediaQueryWrapper = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: settings.timeformat == '12' ? false : true,
            ),
            child: child!,
          );
          return mediaQueryWrapper;
        },
      );
      if (timeStartPicker != null) {
        final String time24h = weatherController.timeTo24h(timeStartPicker);
        isar.writeTxnSync(() {
          settings.timeStart = time24h;
          isar.settings.putSync(settings);
        });
        if (!context.mounted) return;
        MyApp.updateAppState(context, newTimeStart: time24h);
        if (settings.notifications) {
          flutterLocalNotificationsPlugin.cancelAll();
          weatherController.notification(weatherController.mainWeather);
        }
        setState(() {});
      }
    },
  );

  Widget _buildTimeEndSettingCard(BuildContext context, StateSetter setState) =>
      SettingCard(
        elevation: 4,
        icon: const Icon(LucideIcons.timerOff),
        text: 'timeEnd'.tr,
        info: true,
        infoSettings: true,
        infoWidget: _TextInfo(info: weatherController.formatTime(timeEnd)),
        onPressed: () async {
          final TimeOfDay? timeEndPicker = await showTimePicker(
            context: context,
            initialTime: weatherController.parseTime(timeEnd),
            builder: (context, child) {
              final Widget mediaQueryWrapper = MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  alwaysUse24HourFormat: settings.timeformat == '12'
                      ? false
                      : true,
                ),
                child: child!,
              );
              return mediaQueryWrapper;
            },
          );
          if (timeEndPicker != null) {
            final String time24h = weatherController.timeTo24h(timeEndPicker);
            isar.writeTxnSync(() {
              settings.timeEnd = time24h;
              isar.settings.putSync(settings);
            });
            if (!context.mounted) return;
            MyApp.updateAppState(context, newTimeEnd: time24h);
            if (settings.notifications) {
              flutterLocalNotificationsPlugin.cancelAll();
              weatherController.notification(weatherController.mainWeather);
            }
            setState(() {});
          }
        },
      );

  Widget _buildDataCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.slidersHorizontal),
    text: 'data'.tr,
    onPressed: () => _showDataBottomSheet(context),
  );

  void _showDataBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDataTitle(context),
              _buildWeatherDataSourceSettingCard(context, setState),
              if (settings.weatherDataSource == 'hybrid')
                _buildPreferMetNoSettingCard(context, setState),
              _buildRoundDegreeSettingCard(context, setState),
              _buildDegreesSettingCard(context, setState),
              _buildMeasurementsSettingCard(context, setState),
              _buildWindSettingCard(context, setState),
              _buildPressureSettingCard(context, setState),
              _buildTimeFormatSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildDataTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'data'.tr,
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
  );

  Widget _buildWeatherDataSourceSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.cloudSun),
    text: 'Weather Data Source',
    dropdown: true,
    dropdownName: _getDataSourceDisplayName(settings.weatherDataSource),
    dropdownList: <String>['Open-Meteo', 'MET Norway', 'Hybrid (Best of Both)'],
    dropdownChange: (String? newValue) async {
      if (newValue == null) return;
      String sourceValue;
      switch (newValue) {
        case 'MET Norway':
          sourceValue = 'metno';
          break;
        case 'Hybrid (Best of Both)':
          sourceValue = 'hybrid';
          break;
        default:
          sourceValue = 'openmeteo';
      }
      isar.writeTxnSync(() {
        settings.weatherDataSource = sourceValue;
        isar.settings.putSync(settings);
      });

      // Clear cache and refresh data
      await weatherController.deleteAll(false);
      await weatherController.setLocation();
      await weatherController.updateCacheCard(true);
      setState(() {});
    },
  );

  String _getDataSourceDisplayName(String source) {
    switch (source) {
      case 'metno':
        return 'MET Norway';
      case 'hybrid':
        return 'Hybrid (Best of Both)';
      default:
        return 'Open-Meteo';
    }
  }

  Widget _buildRoundDegreeSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.thermometerSun),
    text: 'roundDegree'.tr,
    switcher: true,
    value: settings.roundDegree,
    onChange: (value) {
      settings.roundDegree = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      MyApp.updateAppState(context, newRoundDegree: value);
      setState(() {});
    },
  );

  Widget _buildPreferMetNoSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.mapPin),
    text: 'Prefer MET Norway',
    switcher: true,
    value: settings.preferMetNoInHybrid,
    onChange: (value) async {
      settings.preferMetNoInHybrid = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      // Clear cache and refresh weather data
      await weatherController.deleteAll(false);
      await weatherController.setLocation();
      await weatherController.updateCacheCard(true);
      setState(() {});
    },
  );

  Widget _buildDegreesSettingCard(BuildContext context, StateSetter setState) =>
      SettingCard(
        elevation: 4,
        icon: const Icon(LucideIcons.sun),
        text: 'degrees'.tr,
        dropdown: true,
        dropdownName: settings.degrees.tr,
        dropdownList: <String>['celsius'.tr, 'fahrenheit'.tr],
        dropdownChange: (String? newValue) async {
          isar.writeTxnSync(() {
            settings.degrees = newValue == 'celsius'.tr
                ? 'celsius'
                : 'fahrenheit';
            isar.settings.putSync(settings);
          });
          await weatherController.deleteAll(false);
          await weatherController.setLocation();
          await weatherController.updateCacheCard(true);
          setState(() {});
        },
      );

  Widget _buildMeasurementsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.pencilRuler),
    text: 'measurements'.tr,
    dropdown: true,
    dropdownName: settings.measurements.tr,
    dropdownList: <String>['metric'.tr, 'imperial'.tr],
    dropdownChange: (String? newValue) async {
      isar.writeTxnSync(() {
        settings.measurements = newValue == 'metric'.tr ? 'metric' : 'imperial';
        isar.settings.putSync(settings);
      });
      await weatherController.deleteAll(false);
      await weatherController.setLocation();
      await weatherController.updateCacheCard(true);
      setState(() {});
    },
  );

  Widget _buildWindSettingCard(BuildContext context, StateSetter setState) =>
      SettingCard(
        elevation: 4,
        icon: const Icon(LucideIcons.wind),
        text: 'wind'.tr,
        dropdown: true,
        dropdownName: settings.wind.tr,
        // Dynamically show units based on measurement system
        dropdownList: settings.measurements == 'imperial'
            ? <String>['mph'.tr, 'knots'.tr]
            : <String>['kph'.tr, 'm/s'.tr],
        dropdownChange: (String? newValue) async {
          if (newValue == null) return;

          isar.writeTxnSync(() {
            // Map translated value back to internal keys
            if (newValue == 'mph'.tr) {
              settings.wind = 'mph';
            } else if (newValue == 'knots'.tr)
              settings.wind = 'knots';
            else if (newValue == 'm/s'.tr)
              settings.wind = 'm/s';
            else
              settings.wind = 'kph';

            isar.settings.putSync(settings);
          });

          setState(() {});

          // Refresh the widget to show the new unit
          Get.find<WeatherController>().updateWidget();
        },
      );

  Widget _buildPressureSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.gauge),
    text: 'pressure'.tr,
    dropdown: true,
    dropdownName: settings.pressure.tr,
    dropdownList: <String>['hPa'.tr, 'mmHg'.tr],
    dropdownChange: (String? newValue) async {
      isar.writeTxnSync(() {
        settings.pressure = newValue == 'hPa'.tr ? 'hPa' : 'mmHg';
        isar.settings.putSync(settings);
      });
      setState(() {});
    },
  );

  Widget _buildTimeFormatSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.clock),
    text: 'timeformat'.tr,
    dropdown: true,
    dropdownName: settings.timeformat.tr,
    dropdownList: <String>['12'.tr, '24'.tr],
    dropdownChange: (String? newValue) {
      isar.writeTxnSync(() {
        settings.timeformat = newValue == '12'.tr ? '12' : '24';
        isar.settings.putSync(settings);
      });
      setState(() {});
    },
  );

  Widget _buildAqiIndexSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.wind),
    text: 'Air Quality Index',
    dropdown: true,
    dropdownName: settings.aqiIndex == 'daqi' ? 'UK DAQI' : 'US AQI',
    dropdownList: <String>['UK DAQI', 'US AQI'],
    dropdownChange: (String? newValue) {
      isar.writeTxnSync(() {
        settings.aqiIndex = newValue == 'UK DAQI' ? 'daqi' : 'us';
        isar.settings.putSync(settings);
      });
      setState(() {});
    },
  );

  Widget _buildDummyAlertsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.triangleAlert),
    text: 'Show Dummy Weather Alerts',
    switcher: true,
    value: settings.showDummyAlerts,
    onChange: (value) {
      settings.showDummyAlerts = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildAlertSeveritySettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.info),
    text: 'Minimum Alert Severity',
    dropdown: true,
    dropdownName: _getSeverityDisplayName(settings.alertMinSeverity),
    dropdownList: <String>['Show All', 'Moderate+', 'Severe+', 'Extreme Only'],
    dropdownChange: (String? newValue) {
      if (newValue == null) return;
      String severityValue;
      switch (newValue) {
        case 'Moderate+':
          severityValue = 'moderate';
          break;
        case 'Severe+':
          severityValue = 'severe';
          break;
        case 'Extreme Only':
          severityValue = 'extreme';
          break;
        default:
          severityValue = 'all';
      }
      isar.writeTxnSync(() {
        settings.alertMinSeverity = severityValue;
        isar.settings.putSync(settings);
      });
      setState(() {});
    },
  );

  String _getSeverityDisplayName(String severity) {
    switch (severity) {
      case 'moderate':
        return 'Moderate+';
      case 'severe':
        return 'Severe+';
      case 'extreme':
        return 'Extreme Only';
      default:
        return 'Show All';
    }
  }

  Widget _buildShowAlertsOnMainPageSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.house),
    text: 'Show Alerts on Main Page',
    switcher: true,
    value: settings.showAlertsOnMainPage,
    onChange: (value) {
      settings.showAlertsOnMainPage = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildShowAlertsOnMapSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.map),
    text: 'Show Alerts on Map',
    switcher: true,
    value: settings.showAlertsOnMap,
    onChange: (value) {
      settings.showAlertsOnMap = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildViewAlertHistoryCard(BuildContext context) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.history),
    text: 'View Alert History',
    onPressed: () {
      Navigator.pop(context); // Close settings bottom sheet
      Get.to(() => AlertHistoryPage());
    },
  );

  Widget _buildWidgetCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.settings2300),
    text: 'widget'.tr,
    onPressed: () => _showWidgetBottomSheet(context),
  );

  void _showWidgetBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWidgetTitle(context),
              _buildAddWidgetSettingCard(context, setState),
              _buildWidgetBackgroundSettingCard(context, setState),
              _buildWidgetTextSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildWidgetTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'widget'.tr,
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
  );

  Widget _buildAddWidgetSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.squarePlus),
    text: 'addWidget'.tr,
    onPressed: () async {
      if (!Platform.isAndroid) return;

      // Check for OS support
      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
      if (!supported) {
        showSnackBar(content: 'addWidgetLauncher'.tr);
        return;
      }

      // Show selection menu
      _showWidgetPicker(context);
    },
  );

  void _showWidgetPicker(BuildContext context) {
    final List<Map<String, String>> availableWidgets = [
      {'name': 'current'.tr, 'class': 'OreoWidget'},
      {'name': 'currentForecastWidget'.tr, 'class': 'CurrentWidget'},
      {'name': 'hourlyForecastWidget'.tr, 'class': 'HourlyWidget'},
      {'name': 'dailyForecastWidget'.tr, 'class': 'DailyWidget'},
      {'name': 'smallWidget'.tr, 'class': 'SmallWidget'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'addWidget'.tr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              ...availableWidgets.map(
                (widget) => ListTile(
                  leading: const Icon(LucideIcons.layoutDashboard),
                  title: Text(widget['name']!),
                  onTap: () async {
                    Navigator.pop(context);
                    await HomeWidget.requestPinWidget(
                      name: widget['class']!,
                      androidName: widget['class']!,
                      qualifiedAndroidName: 'com.yoshi.rain.${widget['class']}',
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetBackgroundSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.swatchBook),
    text: 'widgetBackground'.tr,
    info: true,
    infoWidget: CircleAvatar(
      backgroundColor: context.theme.dividerColor,
      radius: 11,
      child: CircleAvatar(
        backgroundColor: widgetBackgroundColor.isEmpty
            ? context.theme.primaryColor
            : HexColor.fromHex(widgetBackgroundColor),
        radius: 10,
      ),
    ),
    onPressed: () {
      colorBackground = null;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildWidgetBackgroundTitle(context),
                _buildColorPicker(context),
                _buildColorPickerButton(context),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildWidgetBackgroundTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'widgetBackground'.tr,
      style: context.textTheme.titleMedium?.copyWith(fontSize: 18),
    ),
  );

  Widget _buildColorPicker(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: Theme(
      data: context.theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: ColorPicker(
        color: widgetBackgroundColor.isEmpty
            ? context.theme.primaryColor
            : HexColor.fromHex(widgetBackgroundColor),
        onChanged: (pickedColor) => colorBackground = pickedColor.toHex(),
      ),
    ),
  );

  Widget _buildColorPickerButton(BuildContext context) => IconButton(
    icon: const Icon(LucideIcons.pipette),
    onPressed: () {
      if (colorBackground == null) {
        return;
      }
      weatherController.updateWidgetBackgroundColor(colorBackground!);
      MyApp.updateAppState(context, newWidgetBackgroundColor: colorBackground);
      Get.back();
    },
  );

  Widget _buildWidgetTextSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.pipette),
    text: 'widgetText'.tr,
    info: true,
    infoWidget: CircleAvatar(
      backgroundColor: context.theme.dividerColor,
      radius: 11,
      child: CircleAvatar(
        backgroundColor: widgetTextColor.isEmpty
            ? context.theme.primaryColor
            : HexColor.fromHex(widgetTextColor),
        radius: 10,
      ),
    ),
    onPressed: () {
      colorText = null;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildWidgetTextTitle(context),
                _buildTextColorPicker(context),
                _buildTextColorPickerButton(context),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildWidgetTextTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'widgetText'.tr,
      style: context.textTheme.titleMedium?.copyWith(fontSize: 18),
    ),
  );

  Widget _buildTextColorPicker(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: Theme(
      data: context.theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      child: ColorPicker(
        color: widgetTextColor.isEmpty
            ? context.theme.primaryColor
            : HexColor.fromHex(widgetTextColor),
        onChanged: (pickedColor) => colorText = pickedColor.toHex(),
      ),
    ),
  );

  Widget _buildTextColorPickerButton(BuildContext context) => IconButton(
    icon: const Icon(LucideIcons.check),
    onPressed: () {
      if (colorText == null) {
        return;
      }
      weatherController.updateWidgetTextColor(colorText!);
      MyApp.updateAppState(context, newWidgetTextColor: colorText);
      Get.back();
    },
  );

  Widget _buildMapCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.map),
    text: 'map'.tr,
    onPressed: () => _showMapBottomSheet(context),
  );

  void _showMapBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapTitle(context),
              _buildHideMapSettingCard(context, setState),
              _buildClearCacheStoreSettingCard(context),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildMapTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'map'.tr,
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
  );

  Widget _buildHideMapSettingCard(BuildContext context, StateSetter setState) =>
      SettingCard(
        elevation: 4,
        icon: const Icon(LucideIcons.eyeOff),
        text: 'hideMap'.tr,
        switcher: true,
        value: settings.hideMap,
        onChange: (value) {
          settings.hideMap = value;
          isar.writeTxnSync(() => isar.settings.putSync(settings));
          setState(() {});
          Future.delayed(
            const Duration(milliseconds: 500),
            () => Restart.restartApp(),
          );
        },
      );

  Widget _buildClearCacheStoreSettingCard(BuildContext context) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.trash),
    text: 'clearCacheStore'.tr,
    onPressed: () => _showClearCacheStoreDialog(context),
  );

  void _showClearCacheStoreDialog(BuildContext context) => showAdaptiveDialog(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text('deletedCacheStore'.tr, style: context.textTheme.titleLarge),
      content: Text(
        'deletedCacheStoreQuery'.tr,
        style: context.textTheme.titleMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text(
            'cancel'.tr,
            style: context.textTheme.titleMedium?.copyWith(
              color: Colors.blueAccent,
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            final dir = await getTemporaryDirectory();
            final cacheStoreFuture = FileCacheStore(
              '${dir.path}${Platform.pathSeparator}MapTiles',
            );
            cacheStoreFuture.clean();
            Get.back();
          },
          child: Text(
            'delete'.tr,
            style: context.textTheme.titleMedium?.copyWith(color: Colors.red),
          ),
        ),
      ],
    ),
  );

  Widget _buildLanguageCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.languages),
    text: 'language'.tr,
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: appLanguages.firstWhere(
        (element) => (element['locale'] == locale),
        orElse: () => {'name': ''},
      )['name'],
    ),
    onPressed: () => _showLanguageBottomSheet(context),
  );

  void _showLanguageBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => ListView(
          children: [
            _buildLanguageTitle(context),
            _buildLanguageList(context),
            const Gap(10),
          ],
        ),
      ),
    ),
  );

  Widget _buildLanguageTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'language'.tr,
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
      textAlign: TextAlign.center,
    ),
  );

  Widget _buildLanguageList(BuildContext context) => ListView.builder(
    shrinkWrap: true,
    physics: const BouncingScrollPhysics(),
    itemCount: appLanguages.length,
    itemBuilder: (context, index) => Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Text(
          appLanguages[index]['name'],
          style: context.textTheme.labelLarge,
          textAlign: TextAlign.center,
        ),
        onTap: () {
          MyApp.updateAppState(
            context,
            newLocale: appLanguages[index]['locale'],
          );
          _updateLanguage(appLanguages[index]['locale']);
        },
      ),
    ),
  );

  Widget _buildLicenseCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.file),
    text: 'license'.tr,
    onPressed: () => Get.to(
      () => LicensePage(
        applicationIcon: Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            image: DecorationImage(image: AssetImage('assets/icons/icon.png')),
          ),
        ),
        applicationName: 'Nimbus',
        applicationVersion: appVersion,
      ),
      transition: Transition.downToUp,
    ),
  );

  Widget _buildVersionCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.gitBranch),
    text: 'version'.tr,
    info: true,
    infoWidget: _TextInfo(info: '$appVersion'),
  );

  Widget _buildGitHubCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.github),
    text: '${'project'.tr} GitHub',
    onPressed: () =>
        weatherController.urlLauncher('https://github.com/linuxgoose/nimbus'),
  );

  Widget _buildSupportCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.mail),
    text: 'Contact Support', // TODO: Need to do translations
    onPressed: () =>
        weatherController.urlLauncher('mailto:support@linuxgoose.com'),
  );

  Widget _buildOpenMeteoText(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: GestureDetector(
      child: Text(
        'openMeteo'.tr,
        style: context.textTheme.bodyMedium,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
      onTap: () => weatherController.urlLauncher('https://open-meteo.com/'),
    ),
  );
}

class _TextInfo extends StatelessWidget {
  const _TextInfo({required this.info});

  final String info;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 5),
    child: Text(
      info,
      style: context.textTheme.bodyMedium,
      overflow: TextOverflow.visible,
    ),
  );
}
