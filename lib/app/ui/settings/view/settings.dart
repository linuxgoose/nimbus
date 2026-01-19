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
  Widget _buildTidesDiscoveryApiKeySettingCard(
    BuildContext context,
    StateSetter setState,
  ) {
    return SettingCard(
      elevation: 4,
      icon: const Icon(LucideIcons.key),
      text: 'UK Tidal API - Discovery Key',
      info: true,
      infoSettings: true,
      infoWidget: _TextInfo(
        info: settings.tidesDiscoveryApiKey?.isNotEmpty == true
            ? '${settings.tidesDiscoveryApiKey!.substring(0, 8)}...'
            : 'Not set',
      ),
      onPressed: () => _showTidesDiscoveryApiKeyDialog(context, setState),
    );
  }

  void _showTidesDiscoveryApiKeyDialog(
    BuildContext context,
    StateSetter setState,
  ) {
    final controller = TextEditingController(
      text: settings.tidesDiscoveryApiKey ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('UK Tidal API - Discovery Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Get your API key from:', style: context.textTheme.bodySmall),
            const SizedBox(height: 8),
            SelectableText(
              'https://www.admiralty.co.uk/uksouthampton/uk-tidal-api',
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
              settings.tidesDiscoveryApiKey = controller.text.trim();
              if (settings.tidesDiscoveryApiKey!.isEmpty) {
                settings.tidesDiscoveryApiKey = null;
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'General', LucideIcons.settings),
        _buildAppearanceCard(context),
        _buildWeatherProviderCard(context),
        _buildFunctionsCard(context),
        _buildLanguageCard(context),

        const Gap(20),
        _buildSectionHeader(context, 'Data Sources', LucideIcons.database),
        _buildTidesCard(context),
        _buildElevationCard(context),
        _buildAuroraCard(context),
        _buildFloodMonitoringCard(context),
        _buildAgricultureCard(context),
        _buildMarineCard(context),
        _buildHikingCard(context),
        _buildWeatherAlertsCard(context),
        _buildAqiCard(context),

        const Gap(20),
        _buildSectionHeader(context, 'System', LucideIcons.smartphone),
        _buildDataCard(context),
        _buildWidgetCard(context),
        _buildMapCard(context),

        const Gap(20),
        _buildSectionHeader(context, 'About', LucideIcons.info),
        _buildLicenseCard(context),
        _buildVersionCard(context),
        _buildGitHubCard(context),
        _buildSupportCard(context),

        const Gap(20),
        _buildSectionHeader(context, 'Attributions', LucideIcons.heart),
        _buildMetNorwayText(context),
        _buildOpenMeteoText(context),
        if (settings.weatherDataSource == 'nimbusmeteo')
          _buildNimbusMeteoText(context),
        const Gap(20),
      ],
    ),
  );

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
    child: Row(
      children: [
        Icon(icon, size: 20, color: context.theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.theme.colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );

  Widget _buildAppearanceCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.paintRoller),
    text: 'appearance'.tr,
    onPressed: () => _showAppearanceBottomSheet(context),
  );

  Widget _buildWeatherProviderCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.cloudSun),
    text: 'Weather Provider',
    onPressed: () => _showWeatherProviderBottomSheet(context),
  );

  void _showWeatherProviderBottomSheet(BuildContext context) =>
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
                  _buildWeatherProviderTitle(context),
                  _buildWeatherDataSourceSettingCard(context, setState),
                  if (settings.weatherDataSource == 'hybrid')
                    _buildPreferMetNoSettingCard(context, setState),
                  _buildGeocodingSourceSettingCard(context, setState),
                  _buildHideRainForecastSettingCard(context, setState),
                  _buildRainNotificationsSettingCard(context, setState),
                  _buildRainThresholdSettingCard(context, setState),
                  _buildNowTileMetricsTitle(context),
                  _buildNowTileMetric1Card(context, setState),
                  _buildNowTileMetric2Card(context, setState),
                  const Gap(10),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildWeatherProviderTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Text(
      'Weather Provider',
      style: context.textTheme.titleLarge?.copyWith(fontSize: 20),
    ),
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
              _buildTidesSourceSettingCard(context, setState),
              if (settings.tidesSource == 'stormglass')
                _buildTidesApiKeySettingCard(context, setState),
              if (settings.tidesSource == 'uk_tidal_api')
                _buildTidesDiscoveryApiKeySettingCard(context, setState),
              _buildTideDatumSettingCard(context, setState),
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

  Widget _buildElevationCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.mountain),
    text: 'Elevation',
    onPressed: () => _showElevationBottomSheet(context),
  );

  Widget _buildAuroraCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.sparkles),
    text: 'Aurora Watch',
    onPressed: () => _showAuroraBottomSheet(context),
  );

  void _showElevationBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildElevationTitle(context),
              _buildHideElevationSettingCard(context, setState),
              _buildUseDummyElevationSettingCard(context, setState),
              _buildElevationSourceSettingCard(context, setState),
              if (settings.elevationSource == 'open_elevation')
                _buildElevationApiKeySettingCard(context, setState),
              _buildCheckElevationCacheSettingCard(context, setState),
              const Gap(10),
              _buildClearElevationCacheSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildElevationTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text('Elevation', style: context.textTheme.headlineSmall),
  );

  void _showAuroraBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAuroraTitle(context),
              _buildHideAuroraSettingCard(context, setState),
              _buildHideEarthEventsSettingCard(context, setState),
              _buildAuroraNotificationsSettingCard(context, setState),
              _buildAuroraThresholdSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildFloodMonitoringCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.waves),
    text: 'UK Flood Monitoring',
    onPressed: () => _showFloodMonitoringBottomSheet(context),
  );

  Widget _buildAgricultureCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.sprout),
    text: 'Agriculture',
    onPressed: () => _showAgricultureBottomSheet(context),
  );

  Widget _buildMarineCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.waves),
    text: 'Marine',
    onPressed: () => _showMarineBottomSheet(context),
  );

  Widget _buildHikingCard(BuildContext context) => SettingCard(
    icon: const Icon(LucideIcons.mountain),
    text: 'Hiking',
    onPressed: () => _showHikingBottomSheet(context),
  );

  void _showFloodMonitoringBottomSheet(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) => StatefulBuilder(
            builder: (BuildContext context, setState) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFloodTitle(context),
                  _buildHideFloodSettingCard(context, setState),
                  _buildFloodNotificationsSettingCard(context, setState),
                  _buildFloodRadiusSettingCard(context, setState),
                  const Gap(10),
                ],
              ),
            ),
          ),
        ),
      );

  void _showAgricultureBottomSheet(BuildContext context) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) => StatefulBuilder(
            builder: (BuildContext context, setState) => SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAgricultureTitle(context),
                  _buildHideAgricultureSettingCard(context, setState),
                  const Gap(10),
                ],
              ),
            ),
          ),
        ),
      );

  void _showMarineBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMarineTitle(context),
              _buildHideMarineSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
  );

  void _showHikingBottomSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHikingTitle(context),
              _buildHideHikingSettingCard(context, setState),
              const Gap(10),
            ],
          ),
        ),
      ),
    ),
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

  void _showWeatherAlertsBottomSheet(
    BuildContext context,
  ) => showModalBottomSheet(
    context: context,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: StatefulBuilder(
        builder: (BuildContext context, setState) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildWeatherAlertsTitle(context),
              _buildWeatherAlertNotificationsSettingCard(context, setState),
              _buildWeatherAlertSeverityThresholdSettingCard(context, setState),
              const Divider(),
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

  Widget _buildWeatherAlertNotificationsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.bell),
    text: 'Weather Alert Notifications',
    switcher: true,
    value: settings.weatherAlertNotifications,
    onChange: (value) {
      settings.weatherAlertNotifications = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      if (value ||
          settings.rainNotifications ||
          settings.auroraNotifications ||
          settings.floodNotifications) {
        WeatherController.scheduleNotificationChecks();
      } else {
        WeatherController.cancelNotificationChecks();
      }
      setState(() {});
    },
  );

  Widget _buildWeatherAlertSeverityThresholdSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.gauge),
    text: 'Notification Severity Threshold',
    dropdown: true,
    dropdownName: _getNotificationSeverityDisplayName(
      settings.weatherAlertMinSeverity,
    ),
    dropdownList: <String>[
      'All Alerts',
      'Moderate+',
      'Severe+',
      'Extreme Only',
    ],
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
        settings.weatherAlertMinSeverity = severityValue;
        isar.settings.putSync(settings);
      });
      setState(() {});
    },
  );

  String _getNotificationSeverityDisplayName(String severity) {
    switch (severity) {
      case 'moderate':
        return 'Moderate+';
      case 'severe':
        return 'Severe+';
      case 'extreme':
        return 'Extreme Only';
      default:
        return 'All Alerts';
    }
  }

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
          // Show test notification immediately to confirm it's working
          await _showTestNotification();
          // Schedule regular forecast notifications
          weatherController.notification(weatherController.mainWeather);
          // Start background worker to reschedule when notifications expire
          WeatherController.scheduleNotificationChecks();
        } else {
          flutterLocalNotificationsPlugin.cancelAll();
          // Cancel background worker if no notification types are enabled
          if (!settings.auroraNotifications &&
              !settings.rainNotifications &&
              !settings.weatherAlertNotifications &&
              !settings.floodNotifications) {
            WeatherController.cancelNotificationChecks();
          }
        }
        setState(() {});
      }
    },
  );

  Future<void> _showTestNotification() async {
    try {
      final androidDetails = const AndroidNotificationDetails(
        'Rain',
        'DARK NIGHT',
        channelDescription: 'Weather forecast notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        999, // Test notification ID
        '✅ Forecast Notifications Enabled',
        'Scheduled weather forecast notifications are now active and will appear according to your update frequency and quiet hours settings.',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

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

  Widget _buildTidesSourceSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.database),
    text: 'Tide Data Source',
    dropdown: true,
    dropdownName: _getTidesSourceDisplayName(settings.tidesSource),
    dropdownList: const <String>[
      'Stormglass',
      'UK Environment Agency',
      'UK Tidal API - Discovery',
    ],
    dropdownChange: (String? newValue) async {
      if (newValue == null) return;

      isar.writeTxnSync(() {
        if (newValue == 'Stormglass') {
          settings.tidesSource = 'stormglass';
        } else if (newValue == 'UK Environment Agency') {
          settings.tidesSource = 'environment_agency';
        } else if (newValue == 'UK Tidal API - Discovery') {
          settings.tidesSource = 'uk_tidal_api';
        }
        isar.settings.putSync(settings);
      });

      setState(() {});
    },
  );

  String _getTidesSourceDisplayName(String source) {
    switch (source) {
      case 'stormglass':
        return 'Stormglass';
      case 'environment_agency':
        return 'UK Environment Agency';
      case 'uk_tidal_api':
        return 'UK Tidal API - Discovery';
      default:
        return 'Stormglass';
    }
  }

  Widget _buildTideDatumSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.ruler),
    text: 'Tide Datum',
    dropdown: true,
    dropdownName: settings.tideDatum.toUpperCase(),
    dropdownList: const <String>['MLLW', 'MLW', 'MSL', 'MHW', 'MHHW'],
    dropdownChange: (String? newValue) async {
      if (newValue == null) return;

      isar.writeTxnSync(() {
        settings.tideDatum = newValue.toLowerCase();
        isar.settings.putSync(settings);
      });

      setState(() {});
    },
  );

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

  Widget _buildHideElevationSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Elevation',
    switcher: true,
    value: settings.hideElevation,
    onChange: (value) {
      settings.hideElevation = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildUseDummyElevationSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.testTube),
    text: 'Use Dummy Elevation Data',
    switcher: true,
    value: settings.useDummyElevation,
    onChange: (value) {
      settings.useDummyElevation = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildElevationSourceSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.database),
    text: 'Elevation Data Source',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: settings.elevationSource == 'open_meteo'
          ? 'Open-Meteo'
          : settings.elevationSource == 'nimbusmeteo'
          ? 'Nimbus Meteo'
          : 'Open-Elevation',
    ),
    onPressed: () => _showElevationSourceDialog(context, setState),
  );

  void _showElevationSourceDialog(BuildContext context, StateSetter setState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elevation Data Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Open-Meteo'),
              subtitle: const Text(
                'Free, no API key required. Fast and reliable.',
              ),
              value: 'open_meteo',
              groupValue: settings.elevationSource,
              onChanged: (value) {
                if (value != null) {
                  settings.elevationSource = value;
                  isar.writeTxnSync(() => isar.settings.putSync(settings));
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Nimbus Meteo'),
              subtitle: const Text(
                'Free, no API key required. Fast and reliable.',
              ),
              value: 'nimbusmeteo',
              groupValue: settings.elevationSource,
              onChanged: (value) {
                if (value != null) {
                  settings.elevationSource = value;
                  isar.writeTxnSync(() => isar.settings.putSync(settings));
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Open-Elevation'),
              subtitle: const Text('Free public API or self-hosted option.'),
              value: 'open_elevation',
              groupValue: settings.elevationSource,
              onChanged: (value) {
                if (value != null) {
                  settings.elevationSource = value;
                  isar.writeTxnSync(() => isar.settings.putSync(settings));
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
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
  }

  Widget _buildAuroraTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 15, top: 10, bottom: 10),
    child: Text(
      'Aurora Watch',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildHideAuroraSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Aurora Watch',
    switcher: true,
    value: settings.hideAurora,
    onChange: (value) {
      settings.hideAurora = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildHideEarthEventsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Earth Events',
    switcher: true,
    value: settings.hideEarthEvents,
    onChange: (value) {
      settings.hideEarthEvents = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildAuroraNotificationsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.bell),
    text: 'Aurora Notifications',
    switcher: true,
    value: settings.auroraNotifications,
    onChange: (value) {
      settings.auroraNotifications = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      if (value ||
          settings.rainNotifications ||
          settings.floodNotifications ||
          settings.weatherAlertNotifications) {
        WeatherController.scheduleNotificationChecks();
      } else {
        WeatherController.cancelNotificationChecks();
      }
      setState(() {});
    },
  );

  Widget _buildAuroraThresholdSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.gauge),
    text: 'Notification Threshold',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: 'Kp ${settings.auroraNotificationThreshold.toStringAsFixed(1)}',
    ),
    onPressed: () => _showAuroraThresholdDialog(context, setState),
  );

  Widget _buildFloodTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 15, top: 10, bottom: 10),
    child: Text(
      'UK Flood Monitoring',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildHideFloodSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Flood Monitoring',
    switcher: true,
    value: settings.hideFlood,
    onChange: (value) {
      settings.hideFlood = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildFloodNotificationsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.bell),
    text: 'Flood Notifications',
    switcher: true,
    value: settings.floodNotifications,
    onChange: (value) {
      settings.floodNotifications = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      if (value ||
          settings.rainNotifications ||
          settings.auroraNotifications ||
          settings.weatherAlertNotifications) {
        WeatherController.scheduleNotificationChecks();
      } else {
        WeatherController.cancelNotificationChecks();
      }
      setState(() {});
    },
  );

  Widget _buildFloodRadiusSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.radius),
    text: 'Search Radius',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: '${settings.floodRadiusKm.toStringAsFixed(0)} km',
    ),
    onPressed: () => _showFloodRadiusDialog(context, setState),
  );

  Widget _buildAgricultureTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 15, top: 10, bottom: 10),
    child: Text(
      'Agriculture',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildHideAgricultureSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Agriculture',
    switcher: true,
    value: settings.hideAgriculture,
    onChange: (value) {
      settings.hideAgriculture = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildMarineTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 15, top: 10, bottom: 10),
    child: Text(
      'Marine',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildHideMarineSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Marine',
    switcher: true,
    value: settings.hideMarine,
    onChange: (value) {
      settings.hideMarine = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildHikingTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      'Hiking',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildHideHikingSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.eyeOff),
    text: 'Hide Hiking',
    switcher: true,
    value: settings.hideHiking,
    onChange: (value) {
      settings.hideHiking = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  void _showFloodRadiusDialog(BuildContext context, StateSetter setState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flood Search Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the radius to search for flood warnings around your location (25-200 km).',
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) => Column(
                children: [
                  Text(
                    '${settings.floodRadiusKm.toStringAsFixed(0)} km',
                    style: context.textTheme.titleLarge,
                  ),
                  Slider(
                    value: settings.floodRadiusKm,
                    min: 25,
                    max: 200,
                    divisions: 35,
                    label: '${settings.floodRadiusKm.toStringAsFixed(0)} km',
                    onChanged: (value) {
                      setDialogState(() {
                        settings.floodRadiusKm = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              isar.writeTxnSync(() => isar.settings.putSync(settings));
              setState(() {});
              Get.back();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildElevationApiKeySettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.key),
    text: 'Open-Elevation API Key',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: settings.elevationApiKey?.isNotEmpty == true
          ? '${settings.elevationApiKey!.substring(0, 8)}...'
          : 'Not set (Public API)',
    ),
    onPressed: () => _showElevationApiKeyDialog(context, setState),
  );

  void _showElevationApiKeyDialog(BuildContext context, StateSetter setState) {
    final controller = TextEditingController(
      text: settings.elevationApiKey ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open-Elevation API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The public API is free and requires no key. You can optionally use your own self-hosted instance:',
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              'https://github.com/Jorl17/open-elevation',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key (Optional)',
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
              settings.elevationApiKey = controller.text.trim();
              if (settings.elevationApiKey!.isEmpty) {
                settings.elevationApiKey = null;
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

  void _showAuroraThresholdDialog(BuildContext context, StateSetter setState) {
    double tempThreshold = settings.auroraNotificationThreshold;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Aurora Notification Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get notified when the Kp index reaches or exceeds this level at your location.',
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Kp Index: ${tempThreshold.toStringAsFixed(1)}',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Slider(
                value: tempThreshold,
                min: 0.0,
                max: 9.0,
                divisions: 18,
                label: tempThreshold.toStringAsFixed(1),
                onChanged: (value) {
                  setDialogState(() {
                    tempThreshold = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _getKpDescription(tempThreshold),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
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
                settings.auroraNotificationThreshold = tempThreshold;
                isar.writeTxnSync(() => isar.settings.putSync(settings));
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _getKpDescription(double kp) {
    if (kp >= 9) return 'Extreme storm - Aurora visible worldwide';
    if (kp >= 7) return 'Severe storm - Aurora visible mid-latitudes';
    if (kp >= 6) return 'Strong storm - Aurora visible lower latitudes';
    if (kp >= 5) return 'Minor storm - Aurora visible high latitudes';
    if (kp >= 4) return 'Active - Aurora possible at high latitudes';
    return 'Quiet to unsettled - Aurora unlikely';
  }

  void _showRainThresholdDialog(BuildContext context, StateSetter setState) {
    double tempThreshold = settings.rainNotificationThreshold;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rain Notification Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get notified when rain is forecast in the next 6 hours that meets or exceeds this amount.',
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Rain Amount: ${tempThreshold.toStringAsFixed(1)}mm',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Slider(
                value: tempThreshold,
                min: 0.1,
                max: 10.0,
                divisions: 99,
                label: '${tempThreshold.toStringAsFixed(1)}mm',
                onChanged: (value) {
                  setDialogState(() {
                    tempThreshold = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                _getRainDescription(tempThreshold),
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
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
                settings.rainNotificationThreshold = tempThreshold;
                isar.writeTxnSync(() => isar.settings.putSync(settings));
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRainDescription(double mm) {
    if (mm >= 8) return 'Heavy rain - significant precipitation';
    if (mm >= 4) return 'Moderate rain - noticeable rainfall';
    if (mm >= 2) return 'Light rain - light precipitation';
    if (mm >= 0.5) return 'Light drizzle - minor precipitation';
    return 'Very light - barely noticeable';
  }

  Widget _buildCheckElevationCacheSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.database),
    text: 'Check Elevation Cache',
    onPressed: () {
      final cacheCount = isar.elevationCaches.countSync();
      final caches = isar.elevationCaches
          .getAllSync([])
          .whereType<ElevationCache>()
          .toList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Elevation Cache Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total cached locations: $cacheCount'),
              if (caches.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Cached Locations:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...caches
                    .take(5)
                    .map(
                      (cache) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${cache.lat?.toStringAsFixed(4)}, ${cache.lon?.toStringAsFixed(4)}',
                          style: context.textTheme.bodySmall,
                        ),
                      ),
                    ),
                if (caches.length > 5)
                  Text(
                    '... and ${caches.length - 5} more',
                    style: context.textTheme.bodySmall,
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

  Widget _buildClearElevationCacheSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.trash2),
    text: 'Clear Elevation Cache',
    onPressed: () {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Elevation Cache'),
          content: const Text(
            'Are you sure you want to clear all cached elevation data?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                isar.writeTxnSync(() {
                  isar.elevationCaches.clearSync();
                });
                Navigator.pop(context);
                // ignore: void_checks
                showSnackBar(content: 'Cleared elevation cache entries');
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
    dropdownList: <String>[
      'Open-Meteo',
      'MET Norway',
      'Hybrid (Open-Meteo + MET Norway)',
      'Nimbus Meteo',
    ],
    dropdownChange: (String? newValue) async {
      if (newValue == null) return;
      String sourceValue;
      switch (newValue) {
        case 'MET Norway':
          sourceValue = 'metno';
          break;
        case 'Hybrid (Open-Meteo + MET Norway)':
          sourceValue = 'hybrid';
          break;
        case 'Nimbus Meteo':
          sourceValue = 'nimbusmeteo';
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
      if (mounted) {
        setState(() {});
      }
    },
  );

  String _getDataSourceDisplayName(String source) {
    switch (source) {
      case 'metno':
        return 'MET Norway';
      case 'hybrid':
        return 'Hybrid (Open-Meteo + MET Norway)';
      case 'nimbusmeteo':
        return 'Nimbus Meteo';
      default:
        return 'Open-Meteo';
    }
  }

  Widget _buildGeocodingSourceSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.search),
    text: 'City Search Provider',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: settings.geocodingSource == 'openmeteo'
          ? 'Open-Meteo'
          : settings.geocodingSource == 'nimbusmeteo'
          ? 'Nimbus Meteo'
          : 'Custom',
    ),
    onPressed: () => _showGeocodingSourceDialog(context, setState),
  );

  void _showGeocodingSourceDialog(BuildContext context, StateSetter setState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('City Search Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Open-Meteo'),
              subtitle: const Text(
                'Public geocoding API with worldwide city data.',
              ),
              value: 'openmeteo',
              groupValue: settings.geocodingSource,
              onChanged: (value) {
                if (value != null) {
                  settings.geocodingSource = value;
                  isar.writeTxnSync(() => isar.settings.putSync(settings));
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Nimbus Meteo'),
              subtitle: const Text(
                'Public geocoding API with worldwide city data (powered by Nominatim).',
              ),
              value: 'nimbusmeteo',
              groupValue: settings.geocodingSource,
              onChanged: (value) {
                if (value != null) {
                  settings.geocodingSource = value;
                  isar.writeTxnSync(() => isar.settings.putSync(settings));
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Custom'),
              subtitle: const Text('Use your custom geocoding URL.'),
              value: 'custom',
              groupValue: settings.geocodingSource,
              onChanged: (value) {
                if (value != null) {
                  settings.geocodingSource = value;
                  isar.writeTxnSync(() => isar.settings.putSync(settings));
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
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

  Widget _buildHideRainForecastSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.cloudRain),
    text: 'Hide 6-Hour Rain Forecast',
    switcher: true,
    value: settings.hideRainForecast,
    onChange: (value) {
      settings.hideRainForecast = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      // Force main page to rebuild by triggering weather controller update
      weatherController.isLoading.refresh();
      setState(() {});
    },
  );

  Widget _buildRainNotificationsSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.bell),
    text: 'Rain Notifications',
    switcher: true,
    value: settings.rainNotifications,
    onChange: (value) {
      settings.rainNotifications = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      if (value ||
          settings.auroraNotifications ||
          settings.floodNotifications ||
          settings.weatherAlertNotifications) {
        WeatherController.scheduleNotificationChecks();
      } else {
        WeatherController.cancelNotificationChecks();
      }
      setState(() {});
    },
  );

  Widget _buildRainThresholdSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.droplet),
    text: 'Rain Threshold',
    info: true,
    infoSettings: true,
    infoWidget: _TextInfo(
      info: '${settings.rainNotificationThreshold.toStringAsFixed(1)}mm',
    ),
    onPressed: () => _showRainThresholdDialog(context, setState),
  );

  Widget _buildPreferMetNoSettingCard(
    BuildContext context,
    StateSetter setState,
  ) => SettingCard(
    elevation: 4,
    icon: const Icon(LucideIcons.mapPin),
    text: 'Prefer MET Norway (Hybrid Mode)',
    switcher: true,
    value: settings.preferMetNoInHybrid,
    onChange: (value) {
      settings.preferMetNoInHybrid = value;
      isar.writeTxnSync(() => isar.settings.putSync(settings));
      setState(() {});
    },
  );

  Widget _buildNowTileMetricsTitle(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 15, top: 20, bottom: 10),
    child: Text(
      'Now Tile Metrics',
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _buildNowTileMetric1Card(BuildContext context, StateSetter setState) {
    final metrics = [
      'humidity',
      'wind',
      'precipitation',
      'uv',
      'feels',
      'none',
    ];
    final labels = [
      'Humidity',
      'Wind Speed',
      'Precipitation Probability',
      'UV Index',
      'Feels Like',
      'None',
    ];

    return SettingCard(
      elevation: 4,
      icon: const Icon(LucideIcons.gauge),
      text: 'First Metric',
      dropdown: true,
      dropdownName: labels[metrics.indexOf(settings.nowTileMetric1)],
      dropdownList: labels,
      dropdownChange: (value) {
        if (value != null) {
          final index = labels.indexOf(value);
          settings.nowTileMetric1 = metrics[index];
          isar.writeTxnSync(() => isar.settings.putSync(settings));
          setState(() {});
        }
      },
    );
  }

  Widget _buildNowTileMetric2Card(BuildContext context, StateSetter setState) {
    final metrics = [
      'humidity',
      'wind',
      'precipitation',
      'uv',
      'feels',
      'none',
    ];
    final labels = [
      'Humidity',
      'Wind Speed',
      'Precipitation Probability',
      'UV Index',
      'Feels Like',
      'None',
    ];

    return SettingCard(
      elevation: 4,
      icon: const Icon(LucideIcons.gauge),
      text: 'Second Metric',
      dropdown: true,
      dropdownName: labels[metrics.indexOf(settings.nowTileMetric2)],
      dropdownList: labels,
      dropdownChange: (value) {
        if (value != null) {
          final index = labels.indexOf(value);
          settings.nowTileMetric2 = metrics[index];
          isar.writeTxnSync(() => isar.settings.putSync(settings));
          setState(() {});
        }
      },
    );
  }

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
  Widget _buildMetNorwayText(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: GestureDetector(
      child: Text(
        'metNorway'.tr,
        style: context.textTheme.bodyMedium,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.center,
      ),
      onTap: () => weatherController.urlLauncher('https://api.met.no/'),
    ),
  );

  Widget _buildNimbusMeteoText(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(
      'Data from Nimbus Meteo, powered by Open-Meteo',
      style: context.textTheme.bodyMedium,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
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
