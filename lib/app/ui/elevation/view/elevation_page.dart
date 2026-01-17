import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/api/elevation_api.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';
import 'package:geocoding/geocoding.dart';

class ElevationPage extends StatefulWidget {
  const ElevationPage({super.key});

  @override
  State<ElevationPage> createState() => _ElevationPageState();
}

class _ElevationPageState extends State<ElevationPage> {
  final ElevationAPI _elevationAPI = ElevationAPI();
  Map<String, dynamic>? _elevationData;
  bool _isLoading = true;
  String? _locationName;
  double? _currentLat;
  double? _currentLon;

  @override
  void initState() {
    super.initState();
    _loadElevationData();
  }

  Future<void> _loadElevationData() async {
    setState(() => _isLoading = true);

    try {
      // Use current location if not set
      if (_currentLat == null || _currentLon == null) {
        _currentLat = settings.location ? locationCache.lat : 51.5074;
        _currentLon = settings.location ? locationCache.lon : -0.1278;
        _locationName = 'Current Location';
      }

      final lat = _currentLat ?? 51.5074;
      final lon = _currentLon ?? -0.1278;

      // Check for cached data first
      final cached = _getCachedElevationData(lat, lon);

      if (cached != null) {
        debugPrint('✓ Elevation: Using cached data');
        setState(() {
          _elevationData = cached;
          _isLoading = false;
        });
        return;
      }

      // Fetch new data if no valid cache
      debugPrint('↓ Elevation: Fetching new data');
      final data = await _elevationAPI.getElevationData(
        lat,
        lon,
        apiKey: settings.elevationApiKey,
        useDummyData: settings.useDummyElevation,
      );

      // Cache the fetched data
      _cacheElevationData(lat, lon, data);

      setState(() {
        _elevationData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Elevation: Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getCachedElevationData(double lat, double lon) {
    // Round to 4 decimal places for consistent key matching
    final roundedLat = (lat * 10000).round() / 10000;
    final roundedLon = (lon * 10000).round() / 10000;
    final locationKey = '${roundedLat}_${roundedLon}';

    debugPrint('🔍 Elevation cache lookup for key: $locationKey');

    final cache = isar.elevationCaches.getByLocationKeySync(locationKey);

    if (cache == null) {
      debugPrint('❌ No elevation cache found');
      return null;
    }

    // Check if cache is expired (older than 7 days)
    if (cache.expiresAt != null && DateTime.now().isAfter(cache.expiresAt!)) {
      debugPrint('⏰ Elevation cache expired, deleting...');
      isar.writeTxnSync(() {
        isar.elevationCaches.deleteSync(cache.id);
      });
      return null;
    }

    // Return cached data
    if (cache.cachedDataJson != null) {
      debugPrint('✓ Returning cached elevation data');
      return jsonDecode(cache.cachedDataJson!) as Map<String, dynamic>;
    }

    return null;
  }

  void _cacheElevationData(double lat, double lon, Map<String, dynamic> data) {
    final now = DateTime.now();
    final expiresAt = now.add(
      const Duration(days: 7),
    ); // Elevation doesn't change

    final roundedLat = (lat * 10000).round() / 10000;
    final roundedLon = (lon * 10000).round() / 10000;
    final locationKey = '${roundedLat}_${roundedLon}';

    debugPrint('💾 Caching elevation data for $locationKey');

    final cache = ElevationCache(
      locationKey: locationKey,
      lat: roundedLat,
      lon: roundedLon,
      cachedDataJson: jsonEncode(data),
      cachedAt: now,
      expiresAt: expiresAt,
    );

    isar.writeTxnSync(() {
      isar.elevationCaches.putByLocationKeySync(cache);
    });

    debugPrint('✓ Elevation data cached until $expiresAt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elevation'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.navigation),
            onPressed: _useCurrentLocation,
            tooltip: 'Use Current Location',
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            onPressed: _showLocationSearchDialog,
            tooltip: 'Search Location',
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadElevationData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _elevationData == null
          ? _buildErrorState()
          : _buildElevationContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 64,
            color: context.theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load elevation data',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadElevationData,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildElevationContent() {
    final elevation = _elevationData!['elevation'] as double;
    final elevationFt = _elevationData!['elevationFt'] as double;
    final source = _elevationData!['source'] as String;

    return RefreshIndicator(
      onRefresh: _loadElevationData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocationCard(),
          const SizedBox(height: 16),
          _buildMainElevationCard(elevation, elevationFt),
          const SizedBox(height: 16),
          _buildEffectsCard(elevation),
          const SizedBox(height: 16),
          _buildInfoCard(source),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
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
                LucideIcons.mapPin,
                color: context.theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _locationName ?? 'Current Location',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_elevationData!['lat'].toStringAsFixed(4)}, ${_elevationData!['lon'].toStringAsFixed(4)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainElevationCard(double elevation, double elevationFt) {
    final description = _elevationAPI.getElevationDescription(elevation);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              LucideIcons.mountain,
              size: 64,
              color: context.theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '${elevation.toStringAsFixed(0)} m',
              style: context.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${elevationFt.toStringAsFixed(0)} ft',
              style: context.textTheme.titleLarge?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                description,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectsCard(double elevation) {
    final pressureEffect = _elevationAPI.getPressureEffect(elevation);
    final boilingPoint = _elevationAPI.getBoilingPoint(elevation);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effects of Elevation',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildEffectItem(
              LucideIcons.gauge,
              'Atmospheric Pressure',
              pressureEffect,
            ),
            const Divider(height: 24),
            _buildEffectItem(
              LucideIcons.thermometer,
              'Water Boiling Point',
              boilingPoint,
            ),
            const Divider(height: 24),
            _buildEffectItem(
              LucideIcons.wind,
              'Oxygen Level',
              elevation > 2500
                  ? 'Reduced (${(100 - (elevation / 100)).toStringAsFixed(0)}% of sea level)'
                  : 'Normal',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String source) {
    return Card(
      color: context.theme.colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              LucideIcons.info,
              size: 20,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Source',
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    source,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _useCurrentLocation() {
    setState(() {
      _currentLat = settings.location ? locationCache.lat : 51.5074;
      _currentLon = settings.location ? locationCache.lon : -0.1278;
      _locationName = 'Current Location';
    });
    _loadElevationData();
  }

  void _showLocationSearchDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Search Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name',
                    prefixIcon: const Icon(LucideIcons.mapPin),
                    suffixIcon: isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(LucideIcons.search),
                            onPressed: () async {
                              final query = nameController.text.trim();
                              if (query.isEmpty) return;

                              setDialogState(() => isSearching = true);
                              try {
                                final locations = await locationFromAddress(
                                  query,
                                );
                                if (locations.isNotEmpty) {
                                  final loc = locations.first;
                                  latController.text = loc.latitude.toString();
                                  lonController.text = loc.longitude.toString();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error searching: ${e.toString()}',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                setDialogState(() => isSearching = false);
                              }
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: latController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    prefixIcon: Icon(LucideIcons.navigation),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lonController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    prefixIcon: Icon(LucideIcons.navigation),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: Enter a location name (e.g., "Mount Everest") and tap search',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final lat = double.tryParse(latController.text.trim());
                final lon = double.tryParse(lonController.text.trim());

                if (lat != null && lon != null) {
                  setState(() {
                    _currentLat = lat;
                    _currentLon = lon;
                    _locationName = name.isNotEmpty
                        ? name
                        : 'Selected Location';
                  });
                  Navigator.pop(context);
                  _loadElevationData();
                }
              },
              child: const Text('Show Elevation'),
            ),
          ],
        ),
      ),
    );
  }
}
