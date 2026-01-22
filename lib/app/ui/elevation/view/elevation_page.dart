import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
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
  ElevationLocation? _selectedLocation;
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

      // Check for cached data first (skip if using dummy data)
      if (!settings.useDummyElevation) {
        final cached = _getCachedElevationData(lat, lon);

        if (cached != null) {
          debugPrint('✓ Elevation: Using cached data');
          setState(() {
            _elevationData = cached;
            _isLoading = false;
          });
          return;
        }
      }

      // Fetch new data if no valid cache
      debugPrint('↓ Elevation: Fetching new data');
      final data = await _elevationAPI.getElevationData(
        lat,
        lon,
        apiKey: settings.elevationApiKey,
        useDummyData: settings.useDummyElevation,
        source: settings.elevationSource,
      );

      // Cache the fetched data (skip if using dummy data)
      if (!settings.useDummyElevation) {
        _cacheElevationData(lat, lon, data);
      }

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
        title: Text('elevation'.tr),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.navigation),
            onPressed: _useCurrentLocation,
            tooltip: 'Use Current Location',
          ),
          IconButton(
            icon: const Icon(LucideIcons.mapPin),
            onPressed: _showLocationPicker,
            tooltip: 'Saved Locations',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showSaveLocationDialog,
        child: const Icon(LucideIcons.bookmark),
        tooltip: 'Save Current Location',
      ),
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
            label: Text('try_again'.tr),
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
      _selectedLocation = null;
      _currentLat = settings.location ? locationCache.lat : 51.5074;
      _currentLon = settings.location ? locationCache.lon : -0.1278;
      _locationName = 'Current Location';
    });
    _loadElevationData();
  }

  void _showLocationPicker() async {
    final locations = isar.elevationLocations.where().findAllSync();

    if (!mounted) return;

    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_saved_locations'.tr),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('select_location'.tr),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: locations.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // Current location option
                return ListTile(
                  leading: const Icon(LucideIcons.navigation),
                  title: Text('current_location'.tr),
                  subtitle: Text(
                    settings.location
                        ? 'Lat: ${locationCache.lat?.toStringAsFixed(4)}, '
                              'Lon: ${locationCache.lon?.toStringAsFixed(4)}'
                        : 'Location permission required',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _useCurrentLocation();
                  },
                );
              }

              final location = locations[index - 1];
              return ListTile(
                leading: Icon(
                  location.isPrimary ? LucideIcons.star : LucideIcons.mapPin,
                  color: location.isPrimary ? Colors.amber : null,
                ),
                title: Text(location.name ?? 'Unknown'),
                subtitle: Text(
                  'Lat: ${location.lat?.toStringAsFixed(4)}, '
                  'Lon: ${location.lon?.toStringAsFixed(4)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        location.isPrimary
                            ? LucideIcons.starOff
                            : LucideIcons.star,
                      ),
                      tooltip: location.isPrimary
                          ? 'Remove as default'
                          : 'Set as default',
                      onPressed: () {
                        isar.writeTxnSync(() {
                          // Clear all primary flags
                          final allLocations = isar.elevationLocations
                              .where()
                              .findAllSync();
                          for (var loc in allLocations) {
                            if (loc.isPrimary) {
                              loc.isPrimary = false;
                              isar.elevationLocations.putSync(loc);
                            }
                          }
                          // Set this location as primary
                          if (!location.isPrimary) {
                            location.isPrimary = true;
                            isar.elevationLocations.putSync(location);
                          }
                        });
                        Navigator.pop(context);
                        if (_selectedLocation?.id == location.id) {
                          _loadElevationData();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: () {
                        isar.writeTxnSync(
                          () => isar.elevationLocations.deleteSync(location.id),
                        );
                        Navigator.pop(context);
                        if (_selectedLocation?.id == location.id) {
                          _useCurrentLocation();
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedLocation = location;
                    _locationName = location.name ?? 'Unknown';
                    _currentLat = location.lat;
                    _currentLon = location.lon;
                  });
                  _loadElevationData();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
        ],
      ),
    );
  }

  void _showSaveLocationDialog() async {
    final nameController = TextEditingController();

    final currentLat =
        _currentLat ?? (settings.location ? locationCache.lat : 51.5074);
    final currentLon =
        _currentLon ?? (settings.location ? locationCache.lon : -0.1278);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('save_location'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Location Name',
                hintText: 'e.g., Denver, Colorado',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Lat: ${currentLat?.toStringAsFixed(4)}, '
              'Lon: ${currentLon?.toStringAsFixed(4)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('save'.tr),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      final newLocation = ElevationLocation()
        ..name = nameController.text
        ..lat = currentLat
        ..lon = currentLon
        ..isPrimary = false
        ..lastUpdated = DateTime.now();
      isar.writeTxnSync(() => isar.elevationLocations.putSync(newLocation));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('location_saved'.tr),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
          title: Text('search_location'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'location_name'.tr,
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
                  decoration: InputDecoration(
                    labelText: 'latitude'.tr,
                    prefixIcon: const Icon(LucideIcons.navigation),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lonController,
                  decoration: InputDecoration(
                    labelText: 'longitude'.tr,
                    prefixIcon: const Icon(LucideIcons.navigation),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'search_tip'.tr,
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
              child: Text('cancel'.tr),
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
                        : 'selected_location'.tr;
                  });
                  Navigator.pop(context);
                  _loadElevationData();
                }
              },
              child: Text('show_elevation'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
