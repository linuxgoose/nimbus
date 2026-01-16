import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart' hide Response;
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nimbus/app/api/api.dart';
import 'package:nimbus/app/api/city_api.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/ui/places/view/place_info.dart';
import 'package:nimbus/app/ui/places/widgets/place_action.dart';
import 'package:nimbus/app/ui/places/widgets/place_card.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_data.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_weather.dart';
import 'package:nimbus/app/ui/widgets/text_form.dart';
import 'package:nimbus/main.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController =
      AnimatedMapController(vsync: this);
  final weatherController = Get.put(WeatherController());
  final statusWeather = StatusWeather();
  final statusData = StatusData();
  final Future<CacheStore> _cacheStoreFuture = _getCacheStore();

  final GlobalKey<ExpandableFabState> _fabKey = GlobalKey<ExpandableFabState>();
  final bool _isDarkMode = Get.theme.brightness == Brightness.dark;

  WeatherCard? _selectedWeatherCard;
  bool _isCardVisible = false;
  late final AnimationController _animationController;
  late final Animation<Offset> _offsetAnimation;
  static const _useTransformerId = 'useTransformerId';
  final bool _useTransformer = true;

  final _focusNode = FocusNode();
  late final TextEditingController _controllerSearch = TextEditingController();

  // State for warnings and their labels
  final List<Polygon> _warningPolygons = [];
  final List<Marker> _warningLabels = [];
  bool _showWarnings = true;

  static Future<CacheStore> _getCacheStore() async {
    final dir = await getTemporaryDirectory();
    return FileCacheStore('${dir.path}${Platform.pathSeparator}MapTiles');
  }

  void _addDummyCumbriaWarning() {
    // Coordinates roughly outlining the Cumbria region
    final List<LatLng> cumbriaPoints = [
      const LatLng(54.12, -3.20), // Barrow-in-Furness
      const LatLng(54.20, -3.55), // St Bees
      const LatLng(54.55, -3.65), // Maryport
      const LatLng(54.90, -3.30), // Silloth
      const LatLng(54.95, -2.90), // Carlisle
      const LatLng(54.75, -2.45), // Alston
      const LatLng(54.40, -2.30), // Kirkby Stephen
      const LatLng(54.20, -2.60), // Sedbergh
      const LatLng(54.10, -2.85), // Milnthorpe
    ];

    final color = _getSeverityColor('severe');

    final dummyPolygon = Polygon(
      points: cumbriaPoints,
      color: _getSeverityColor('severe').withOpacity(0.3),
      borderColor: _getSeverityColor('severe'),
      borderStrokeWidth: 3,
    );

    _warningLabels.add(
      Marker(
        point: _getPolygonCenter(cumbriaPoints),
        width: 150,
        height: 40,
        child: _buildAlertLabel("Severe Flood Warning", color),
      ),
    );

    setState(() {
      _warningPolygons.add(dummyPolygon);
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _fetchWeatherAlerts();
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    _controllerSearch.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Helper to find the center of a polygon for the label
  LatLng _getPolygonCenter(List<LatLng> points) {
    double lat = 0;
    double lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  Widget _buildAlertLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchWeatherAlerts() async {
    setState(() {
      _warningPolygons.clear();
      _warningLabels.clear();
    });

    // Check if dummy alerts should be shown
    if (settings.showDummyAlerts) {
      _addDummyCumbriaWarning();
      return;
    }

    // Otherwise, fetch real alerts from API
    try {
      final lat = weatherController.location.lat;
      final lon = weatherController.location.lon;

      if (lat == null || lon == null) return;

      final List alerts = await WeatherAPI().getRawAlerts(lat, lon);

      for (var alert in alerts) {
        if (alert['boundaries'] != null) {
          final features = alert['boundaries']['features'] as List;
          for (var feature in features) {
            final geometry = feature['geometry'];
            if (geometry['type'] == 'Polygon') {
              final List coords = geometry['coordinates'][0];
              final points = coords.map((c) => LatLng(c[1], c[0])).toList();
              final color = _getSeverityColor(alert['severity']);

              setState(() {
                _warningPolygons.add(
                  Polygon(
                    points: points,
                    color: color.withOpacity(0.3),
                    borderColor: color,
                    borderStrokeWidth: 2,
                  ),
                );

                _warningLabels.add(
                  Marker(
                    point: _getPolygonCenter(points),
                    width: 120,
                    height: 40,
                    child: _buildAlertLabel(
                      alert['event'] ?? "Weather Alert",
                      color,
                    ),
                  ),
                );
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Alerts Error: $e");
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'extreme':
        return Colors.red;
      case 'severe':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow;
      default:
        return Colors.blue;
    }
  }

  void _resetMapOrientation({LatLng? center, double? zoom}) =>
      _animatedMapController.animateTo(
        customId: _useTransformer ? _useTransformerId : null,
        dest: center,
        zoom: zoom,
        rotation: 0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

  void _onMarkerTap(WeatherCard weatherCard) {
    setState(() => _selectedWeatherCard = weatherCard);
    _animationController.forward();
    _isCardVisible = true;
    if (_fabKey.currentState?.isOpen == true) _fabKey.currentState?.toggle();
  }

  void _hideCard() {
    _animationController.reverse().then(
      (_) => setState(() {
        _isCardVisible = false;
        _selectedWeatherCard = null;
      }),
    );
    _focusNode.unfocus();
  }

  Widget _buildStyleMarkers(
    int? weathercode,
    String time,
    String sunrise,
    String sunset,
    double? temperature2M,
  ) => Card(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Image.asset(
            statusWeather.getImageNow(weathercode, time, sunrise, sunset),
            scale: 18,
          ),
        ),
        Text(
          statusData.getDegree(
            roundDegree ? (temperature2M ?? 0).round() : (temperature2M ?? 0),
          ),
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Gap(6),
      ],
    ),
  );

  Marker _buildMainLocationMarker(
    WeatherCard weatherCard,
    int hourOfDay,
    int dayOfNow,
  ) => Marker(
    height: 50,
    width: 100,
    point: LatLng(weatherCard.lat!, weatherCard.lon!),
    child: GestureDetector(
      onTap: () => _onMarkerTap(weatherCard),
      child: _buildStyleMarkers(
        weatherCard.weathercode![hourOfDay],
        weatherCard.time![hourOfDay],
        weatherCard.sunrise![dayOfNow.clamp(
          0,
          (weatherCard.sunrise?.length ?? 1) - 1,
        )],
        weatherCard.sunset![dayOfNow.clamp(
          0,
          (weatherCard.sunset?.length ?? 1) - 1,
        )],
        weatherCard.temperature2M?[hourOfDay],
      ),
    ),
  );

  Marker _buildCardMarker(WeatherCard weatherCardList) {
    final hourOfDay = weatherController.getTime(
      weatherCardList.time!,
      weatherCardList.timezone!,
    );
    var dayOfNow = weatherController.getDay(
      weatherCardList.timeDaily!,
      weatherCardList.timezone!,
    );

    // Ensure dayOfNow is within bounds
    final maxDayIndex =
        [
          weatherCardList.sunrise?.length ?? 0,
          weatherCardList.sunset?.length ?? 0,
        ].reduce((a, b) => a < b ? a : b) -
        1;

    if (dayOfNow > maxDayIndex || dayOfNow < 0) {
      dayOfNow = 0;
    }

    return Marker(
      height: 50,
      width: 100,
      point: LatLng(weatherCardList.lat!, weatherCardList.lon!),
      child: GestureDetector(
        onTap: () => _onMarkerTap(weatherCardList),
        child: _buildStyleMarkers(
          weatherCardList.weathercode![hourOfDay],
          weatherCardList.time![hourOfDay],
          weatherCardList.sunrise![dayOfNow],
          weatherCardList.sunset![dayOfNow],
          weatherCardList.temperature2M?[hourOfDay],
        ),
      ),
    );
  }

  Widget _buildMapTileLayer(CacheStore cacheStore) => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.darkmoonight.rain',
    tileProvider: CachedTileProvider(
      store: cacheStore,
      maxStale: const Duration(days: 30),
    ),
  );

  Widget _buildWeatherCard() => _isCardVisible && _selectedWeatherCard != null
      ? SlideTransition(
          position: _offsetAnimation,
          child: GestureDetector(
            onTap: () => Get.to(
              () => PlaceInfo(weatherCard: _selectedWeatherCard!),
              transition: Transition.downToUp,
            ),
            child: PlaceCard(
              time: _selectedWeatherCard!.time!,
              timeDaily: _selectedWeatherCard!.timeDaily!,
              timeDay: _selectedWeatherCard!.sunrise!,
              timeNight: _selectedWeatherCard!.sunset!,
              weather: _selectedWeatherCard!.weathercode!,
              degree: _selectedWeatherCard!.temperature2M!,
              district: _selectedWeatherCard!.district!,
              city: _selectedWeatherCard!.city!,
              timezone: _selectedWeatherCard!.timezone!,
            ),
          ),
        )
      : const SizedBox.shrink();

  Widget _buildSearchField() => RawAutocomplete<Result>(
    focusNode: _focusNode,
    textEditingController: _controllerSearch,
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        MyTextForm(
          labelText: 'search'.tr,
          type: TextInputType.text,
          icon: const Icon(LucideIcons.search),
          controller: controller,
          margin: const EdgeInsets.all(10),
          focusNode: focusNode,
          onChanged: (value) => setState(() {}),
          iconButton: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () => controller.clear(),
                  icon: const Icon(
                    LucideIcons.circleX,
                    color: Colors.grey,
                    size: 20,
                  ),
                )
              : null,
        ),
    optionsBuilder: (textValue) => textValue.text.isEmpty
        ? const Iterable<Result>.empty()
        : WeatherAPI().getCity(textValue.text, locale),
    onSelected: (selection) {
      _animatedMapController.mapController.move(
        LatLng(selection.latitude, selection.longitude),
        14,
      );
      _controllerSearch.clear();
      _focusNode.unfocus();
    },
    displayStringForOption: (option) => '${option.name}, ${option.admin1}',
    optionsViewBuilder: (context, onSelected, options) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          borderRadius: BorderRadius.circular(20),
          elevation: 4,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                title: Text(
                  '${option.name}, ${option.admin1}',
                  style: context.textTheme.labelLarge,
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mainLocation = weatherController.location;
    final mainWeather = weatherController.mainWeather;
    final hourOfDay = weatherController.hourOfDay.value;
    final dayOfNow = weatherController.dayOfNow.value;

    return Scaffold(
      body: FutureBuilder<CacheStore>(
        future: _cacheStoreFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cacheStore = snapshot.data!;

          return Stack(
            children: [
              FlutterMap(
                mapController: _animatedMapController.mapController,
                options: MapOptions(
                  backgroundColor: context.theme.colorScheme.surface,
                  initialCenter: LatLng(
                    mainLocation.lat ?? 51.5074, // Default to London, UK
                    mainLocation.lon ?? -0.1278,
                  ),
                  initialZoom: 8,
                  onTap: (_, __) => _hideCard(),
                  onLongPress: (pos, point) => showModalBottomSheet(
                    context: context,
                    builder: (_) => PlaceAction(
                      latitude: '${point.latitude}',
                      longitude: '${point.longitude}',
                      edit: false,
                    ),
                  ),
                ),
                children: [
                  if (_isDarkMode)
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        -0.2,
                        -0.7,
                        -0.08,
                        0,
                        255,
                        -0.2,
                        -0.7,
                        -0.08,
                        0,
                        255,
                        -0.2,
                        -0.7,
                        -0.08,
                        0,
                        255,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: _buildMapTileLayer(cacheStore),
                    )
                  else
                    _buildMapTileLayer(cacheStore),

                  // Warnings Layers
                  if (_showWarnings) ...[
                    PolygonLayer(polygons: _warningPolygons),
                    MarkerLayer(markers: _warningLabels),
                  ],

                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap',
                        onTap: () => weatherController.urlLauncher(
                          'https://openstreetmap.org/copyright',
                        ),
                      ),
                    ],
                  ),

                  Obx(() {
                    final mainMarker = _buildMainLocationMarker(
                      WeatherCard.fromJson({
                        ...mainWeather.toJson(),
                        ...mainLocation.toJson(),
                      }),
                      hourOfDay,
                      dayOfNow,
                    );
                    final cardMarkers = weatherController.weatherCards
                        .map((c) => _buildCardMarker(c))
                        .toList();
                    return MarkerLayer(markers: [mainMarker, ...cardMarkers]);
                  }),

                  ExpandableFab(
                    key: _fabKey,
                    pos: ExpandableFabPos.right,
                    type: ExpandableFabType.up,
                    distance: 70,
                    children: [
                      FloatingActionButton(
                        heroTag: 'home',
                        child: const Icon(LucideIcons.house),
                        onPressed: () => _resetMapOrientation(
                          center: LatLng(
                            mainLocation.lat ??
                                51.5074, // Default to London, UK
                            mainLocation.lon ?? -0.1278,
                          ),
                          zoom: 8,
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: 'warnings',
                        child: Icon(
                          _showWarnings
                              ? LucideIcons.triangleAlert
                              : LucideIcons.slash,
                        ),
                        onPressed: () =>
                            setState(() => _showWarnings = !_showWarnings),
                      ),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        child: const Icon(LucideIcons.zoomOut),
                        onPressed: () =>
                            _animatedMapController.animatedZoomOut(),
                      ),
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        child: const Icon(LucideIcons.zoomIn),
                        onPressed: () =>
                            _animatedMapController.animatedZoomIn(),
                      ),
                    ],
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildWeatherCard(),
                  ),
                ],
              ),
              _buildSearchField(),
            ],
          );
        },
      ),
      floatingActionButtonLocation: ExpandableFab.location,
    );
  }
}
