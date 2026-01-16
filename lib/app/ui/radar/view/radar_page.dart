import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:get/get.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage> {
  final weatherController = Get.put(WeatherController());
  late final MapController _mapController;
  final bool _isDarkMode = Get.theme.brightness == Brightness.dark;

  List<int> _radarTimestamps = [];
  int _currentTimestampIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  Timer? _animationTimer;
  int _selectedColorScheme = 2; // RainViewer color scheme (0-8)

  static const double _radarOpacity = 0.6; // 0.0-1.0 for tile layer opacity
  static const String _radarType =
      'radar'; // Use 'radar' for actual radar imagery, 'satellite' for satellite

  late Future<CacheStore> _cacheStoreFuture;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _cacheStoreFuture = _initCacheStore();
    _fetchRadarTimestamps();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<CacheStore> _initCacheStore() async {
    final dir = await getTemporaryDirectory();
    return FileCacheStore('${dir.path}${Platform.pathSeparator}RadarTiles');
  }

  Future<void> _fetchRadarTimestamps() async {
    setState(() => _isLoading = true);

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.rainviewer.com/public/weather-maps.json',
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic>? radar = response.data['radar']?['past'];
        final List<dynamic>? nowcast = response.data['radar']?['nowcast'];

        if (radar != null) {
          _radarTimestamps = radar
              .map<int>((item) => item['time'] as int)
              .toList();

          // Add nowcast (future predictions) if available
          if (nowcast != null && nowcast.isNotEmpty) {
            _radarTimestamps.addAll(
              nowcast.map<int>((item) => item['time'] as int),
            );
          }

          // Start at the most recent past timestamp
          _currentTimestampIndex = radar.length - 1;

          // Debug: Print info
          debugPrint('Radar timestamps loaded: ${_radarTimestamps.length}');
          if (_radarTimestamps.isNotEmpty) {
            debugPrint(
              'Current timestamp: ${_radarTimestamps[_currentTimestampIndex]}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching radar timestamps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load radar data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _stopAnimation();
    } else {
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (_radarTimestamps.isEmpty) return;

    setState(() => _isPlaying = true);

    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _currentTimestampIndex =
            (_currentTimestampIndex + 1) % _radarTimestamps.length;
      });
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _goToPreviousFrame() {
    if (_radarTimestamps.isEmpty) return;

    setState(() {
      _currentTimestampIndex =
          (_currentTimestampIndex - 1 + _radarTimestamps.length) %
          _radarTimestamps.length;
    });
  }

  void _goToNextFrame() {
    if (_radarTimestamps.isEmpty) return;

    setState(() {
      _currentTimestampIndex =
          (_currentTimestampIndex + 1) % _radarTimestamps.length;
    });
  }

  void _centerOnLocation() {
    final mainLocation = weatherController.location;
    if (mainLocation.lat != null && mainLocation.lon != null) {
      _mapController.move(LatLng(mainLocation.lat!, mainLocation.lon!), 8.0);
    }
  }

  void _showColorSchemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.layers, color: context.theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Radar Color Scheme'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorSchemeOption(
                scheme: 0,
                name: 'Original',
                description: 'Black and white',
              ),
              _buildColorSchemeOption(
                scheme: 1,
                name: 'Universal Blue',
                description: 'Blue tones only',
              ),
              _buildColorSchemeOption(
                scheme: 2,
                name: 'TITAN',
                description: 'Classic weather radar',
              ),
              _buildColorSchemeOption(
                scheme: 3,
                name: 'The Weather Channel',
                description: 'TWC color scheme',
              ),
              _buildColorSchemeOption(
                scheme: 4,
                name: 'Meteored',
                description: 'Meteored style',
              ),
              _buildColorSchemeOption(
                scheme: 5,
                name: 'NEXRAD',
                description: 'US NEXRAD radar',
              ),
              _buildColorSchemeOption(
                scheme: 6,
                name: 'Rainbow',
                description: 'Full spectrum',
              ),
              _buildColorSchemeOption(
                scheme: 7,
                name: 'Dark Sky',
                description: 'Dark Sky app style',
              ),
              _buildColorSchemeOption(
                scheme: 8,
                name: 'Spectrum',
                description: 'Extended spectrum',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSchemeOption({
    required int scheme,
    required String name,
    required String description,
  }) => RadioListTile<int>(
    value: scheme,
    groupValue: _selectedColorScheme,
    onChanged: (value) {
      if (value != null) {
        setState(() {
          _selectedColorScheme = value;
        });
        Navigator.of(context).pop();
      }
    },
    title: Text(name),
    subtitle: Text(
      description,
      style: context.textTheme.bodySmall?.copyWith(
        color: context.theme.colorScheme.onSurfaceVariant,
      ),
    ),
    dense: true,
  );

  void _showLegend() {
    // Get color scheme name
    final schemeNames = [
      'Original',
      'Universal Blue',
      'TITAN',
      'The Weather Channel',
      'Meteored',
      'NEXRAD',
      'Rainbow',
      'Dark Sky',
      'Spectrum',
    ];
    final schemeName = schemeNames[_selectedColorScheme];

    // Get colors for the selected scheme
    final colors = _getColorSchemeColors(_selectedColorScheme);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.radar, color: context.theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Radar Legend'),
                  Text(
                    schemeName,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Precipitation Intensity',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(colors.length, (index) {
                return _buildLegendItem(
                  color: colors[index],
                  label: _getLabelForIndex(index),
                  value: _getValueForIndex(index),
                );
              }),
              const SizedBox(height: 16),
              Text(
                'Note: Colors may indicate rain, snow, or mixed precipitation depending on temperature.',
                style: context.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Color> _getColorSchemeColors(int scheme) {
    // These are approximate colors based on RainViewer's color schemes
    switch (scheme) {
      case 0: // Original (black and white)
        return [
          const Color(0xFF181818),
          const Color(0xFF2B2B2B),
          const Color(0xFF3E3E3E),
          const Color(0xFF515151),
          const Color(0xFF646464),
          const Color(0xFF777777),
          const Color(0xFF8A8A8A),
          const Color(0xFF9D9D9D),
          const Color(0xFFB0B0B0),
          const Color(0xFFC3C3C3),
        ];
      case 1: // Universal Blue
        return [
          const Color(0xFF0000FF),
          const Color(0xFF0033FF),
          const Color(0xFF0066FF),
          const Color(0xFF0099FF),
          const Color(0xFF00CCFF),
          const Color(0xFF00FFFF),
          const Color(0xFF33FFFF),
          const Color(0xFF66FFFF),
          const Color(0xFF99FFFF),
          const Color(0xFFCCFFFF),
        ];
      case 2: // TITAN
        return [
          const Color(0xFF04E9E7),
          const Color(0xFF019FF4),
          const Color(0xFF0300F4),
          const Color(0xFF02FD02),
          const Color(0xFF01C501),
          const Color(0xFFFDF802),
          const Color(0xFFE5BC00),
          const Color(0xFFFD9500),
          const Color(0xFFFD0000),
          const Color(0xFFD40000),
        ];
      case 3: // The Weather Channel
        return [
          const Color(0xFF00E0FF),
          const Color(0xFF0096FF),
          const Color(0xFF0000FF),
          const Color(0xFF00FF00),
          const Color(0xFF00D000),
          const Color(0xFFFFFF00),
          const Color(0xFFFFCC00),
          const Color(0xFFFF9900),
          const Color(0xFFFF0000),
          const Color(0xFFCC0000),
        ];
      case 4: // Meteored
        return [
          const Color(0xFF0AF5F5),
          const Color(0xFF00A5F5),
          const Color(0xFF0000F5),
          const Color(0xFF00F500),
          const Color(0xFF00C800),
          const Color(0xFFF5F500),
          const Color(0xFFF5C800),
          const Color(0xFFF59600),
          const Color(0xFFF50000),
          const Color(0xFFC80000),
        ];
      case 5: // NEXRAD
        return [
          const Color(0xFF00ECEC),
          const Color(0xFF01A0F6),
          const Color(0xFF0000F6),
          const Color(0xFF00F600),
          const Color(0xFF00C400),
          const Color(0xFFF6F600),
          const Color(0xFFE7BE00),
          const Color(0xFFF69600),
          const Color(0xFFF60000),
          const Color(0xFFDA0000),
        ];
      case 6: // Rainbow
        return [
          const Color(0xFF9400D3),
          const Color(0xFF4B0082),
          const Color(0xFF0000FF),
          const Color(0xFF00FF00),
          const Color(0xFFFFFF00),
          const Color(0xFFFF7F00),
          const Color(0xFFFF0000),
          const Color(0xFFFF1493),
          const Color(0xFFFF00FF),
          const Color(0xFFFFFFFF),
        ];
      case 7: // Dark Sky
        return [
          const Color(0xFF3FBFFF),
          const Color(0xFF0099FF),
          const Color(0xFF0044FF),
          const Color(0xFF00DD00),
          const Color(0xFF00AA00),
          const Color(0xFFFFDD00),
          const Color(0xFFFFAA00),
          const Color(0xFFFF5500),
          const Color(0xFFFF0000),
          const Color(0xFFBB0000),
        ];
      case 8: // Spectrum
        return [
          const Color(0xFF00FFFF),
          const Color(0xFF00AAFF),
          const Color(0xFF0000FF),
          const Color(0xFF00FF00),
          const Color(0xFF00DD00),
          const Color(0xFFFFFF00),
          const Color(0xFFFFDD00),
          const Color(0xFFFFAA00),
          const Color(0xFFFF0000),
          const Color(0xFFDD0000),
        ];
      default:
        return _getColorSchemeColors(2); // Default to TITAN
    }
  }

  String _getLabelForIndex(int index) {
    const labels = [
      'Light',
      'Light-Moderate',
      'Moderate',
      'Moderate-Heavy',
      'Heavy',
      'Heavy',
      'Very Heavy',
      'Very Heavy',
      'Extreme',
      'Extreme',
    ];
    return index < labels.length ? labels[index] : 'Unknown';
  }

  String _getValueForIndex(int index) {
    const values = [
      '0.1 - 1 mm/h',
      '1 - 2 mm/h',
      '2 - 4 mm/h',
      '4 - 10 mm/h',
      '10 - 16 mm/h',
      '16 - 30 mm/h',
      '30 - 50 mm/h',
      '50 - 75 mm/h',
      '75 - 100 mm/h',
      '100+ mm/h',
    ];
    return index < values.length ? values[index] : '';
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String value,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: context.textTheme.bodyMedium)),
        Text(
          value,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();

    if (dateTime.isAfter(now)) {
      final diff = dateTime.difference(now);
      return '+${diff.inMinutes}min';
    } else {
      final diff = now.difference(dateTime);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}min ago';
      } else {
        return '${diff.inHours}h ago';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainLocation = weatherController.location;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Radar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.layers),
            onPressed: _showColorSchemeDialog,
            tooltip: 'Color Scheme',
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _fetchRadarTimestamps,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<CacheStore>(
        future: _cacheStoreFuture,
        builder: (context, cacheSnapshot) {
          if (!cacheSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cacheStore = cacheSnapshot.data!;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  backgroundColor: context.theme.colorScheme.surface,
                  initialCenter: LatLng(
                    mainLocation.lat ?? 0.0,
                    mainLocation.lon ?? 0.0,
                  ),
                  initialZoom: 8,
                  maxZoom: 18,
                  minZoom: 3,
                ),
                children: [
                  // Base map layer
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
                      child: _buildBaseTileLayer(cacheStore),
                    )
                  else
                    _buildBaseTileLayer(cacheStore),

                  // Radar overlay
                  if (!_isLoading && _radarTimestamps.isNotEmpty)
                    Opacity(
                      opacity: _radarOpacity,
                      child: TileLayer(
                        urlTemplate:
                            'https://tilecache.rainviewer.com/v2/$_radarType/${_radarTimestamps[_currentTimestampIndex]}/256/{z}/{x}/{y}/$_selectedColorScheme/1_1.png',
                        userAgentPackageName: 'com.darkmoonight.rain',
                        tileProvider: CachedTileProvider(
                          store: cacheStore,
                          maxStale: const Duration(minutes: 30),
                        ),
                      ),
                    ),

                  // Attribution
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap',
                        onTap: () => weatherController.urlLauncher(
                          'https://openstreetmap.org/copyright',
                        ),
                      ),
                      TextSourceAttribution(
                        'RainViewer',
                        onTap: () => weatherController.urlLauncher(
                          'https://www.rainviewer.com/',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Loading indicator
              if (_isLoading) const Center(child: CircularProgressIndicator()),

              // No data indicator
              if (!_isLoading && _radarTimestamps.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.triangleAlert,
                        size: 64,
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No radar data available',
                        style: context.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _fetchRadarTimestamps,
                        icon: const Icon(LucideIcons.refreshCw),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              // Controls overlay
              if (!_isLoading && _radarTimestamps.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildControlsPanel(),
                ),

              // Data status indicator
              if (!_isLoading && _radarTimestamps.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.radar,
                          size: 16,
                          color: context.theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live Radar',
                          style: context.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Legend button
              Positioned(
                right: 16,
                bottom: 180,
                child: FloatingActionButton(
                  heroTag: 'legend',
                  mini: true,
                  onPressed: _showLegend,
                  child: const Icon(LucideIcons.info),
                ),
              ),

              // Center on location button
              Positioned(
                right: 16,
                bottom: 120,
                child: FloatingActionButton(
                  heroTag: 'center',
                  mini: true,
                  onPressed: _centerOnLocation,
                  child: const Icon(LucideIcons.mapPin),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBaseTileLayer(CacheStore cacheStore) => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.darkmoonight.rain',
    tileProvider: CachedTileProvider(
      store: cacheStore,
      maxStale: const Duration(days: 30),
    ),
  );

  Widget _buildControlsPanel() => Container(
    decoration: BoxDecoration(
      color: context.theme.colorScheme.surface.withOpacity(0.95),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timestamp display
        Text(
          _radarTimestamps.isNotEmpty
              ? _formatTimestamp(_radarTimestamps[_currentTimestampIndex])
              : 'Loading...',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Timeline slider
        if (_radarTimestamps.length > 1)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            ),
            child: Slider(
              value: _currentTimestampIndex.toDouble(),
              min: 0,
              max: (_radarTimestamps.length - 1).toDouble(),
              divisions: _radarTimestamps.length - 1,
              onChanged: (value) {
                setState(() {
                  _currentTimestampIndex = value.round();
                });
              },
            ),
          ),

        const SizedBox(height: 8),

        // Playback controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.skipBack),
              onPressed: _goToPreviousFrame,
              tooltip: 'Previous frame',
            ),
            const SizedBox(width: 16),
            IconButton.filled(
              icon: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play),
              onPressed: _togglePlayPause,
              iconSize: 32,
              tooltip: _isPlaying ? 'Pause' : 'Play',
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(LucideIcons.skipForward),
              onPressed: _goToNextFrame,
              tooltip: 'Next frame',
            ),
          ],
        ),
      ],
    ),
  );
}
