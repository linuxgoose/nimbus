import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/api/tides_api.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

class TidesPage extends StatefulWidget {
  const TidesPage({super.key});

  @override
  State<TidesPage> createState() => _TidesPageState();
}

class _TidesPageState extends State<TidesPage> {
  final TidesAPI _tidesAPI = TidesAPI();
  TideLocation? _selectedLocation;
  SavedTideStation? _selectedStation; // For UK Tidal API
  Map<String, dynamic>? _tideData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrimaryLocation();
  }

  Future<void> _loadPrimaryLocation() async {
    setState(() => _isLoading = true);

    // For UK Tidal API, use saved stations
    if (settings.tidesSource == 'uk_tidal_api') {
      final stations = isar.savedTideStations.where().findAllSync();
      _selectedStation =
          stations.where((s) => s.isPrimary).firstOrNull ??
          stations.firstOrNull;

      // If no saved stations, show station browser
      if (_selectedStation == null) {
        setState(() => _isLoading = false);
        return;
      }

      await _fetchTideData();
      return;
    }

    // For other sources, use lat/lon locations
    final locations = isar.tideLocations.where().findAllSync();
    _selectedLocation =
        locations.where((l) => l.isPrimary).firstOrNull ??
        locations.firstOrNull;

    if (_selectedLocation == null) {
      // Use current weather location as default
      final lat = settings.location ? locationCache.lat : 51.5074;
      final lon = settings.location ? locationCache.lon : -0.1278;

      _selectedLocation = TideLocation(
        name: 'Current Location',
        lat: lat,
        lon: lon,
        isPrimary: true,
      );
    }

    await _fetchTideData();
  }

  Future<void> _fetchTideData() async {
    setState(() => _isLoading = true);

    try {
      // For UK Tidal API - Discovery, use station ID if available
      if (settings.tidesSource == 'uk_tidal_api') {
        if (_selectedStation == null) {
          setState(() => _isLoading = false);
          return;
        }

        debugPrint(
          '↓ Tides: Fetching data for station ${_selectedStation!.stationId}',
        );
        final data = await _tidesAPI.getTideData(
          _selectedStation!.lat,
          _selectedStation!.lon,
          apiKey: settings.tidesDiscoveryApiKey,
          useDummyData: settings.useDummyTides,
          stationId: _selectedStation!.stationId,
        );
        setState(() {
          _tideData = data;
          _isLoading = false;
        });
        return;
      }

      // For other sources, require a location
      if (_selectedLocation == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Check for cached data first (not for UK Tidal API)
      final cached = _getCachedTideData(
        _selectedLocation!.lat!,
        _selectedLocation!.lon!,
      );

      if (cached != null) {
        debugPrint('✓ Tides: Using cached data for ${_selectedLocation!.name}');
        setState(() {
          _tideData = cached;
          _isLoading = false;
        });
        return;
      }

      // Fetch new data if no valid cache
      debugPrint('↓ Tides: Fetching new data for ${_selectedLocation!.name}');
      final data = await _tidesAPI.getTideData(
        _selectedLocation!.lat!,
        _selectedLocation!.lon!,
        apiKey: settings.tidesApiKey,
        useDummyData: settings.useDummyTides,
      );

      // Cache the fetched data
      _cacheTideData(_selectedLocation!.lat!, _selectedLocation!.lon!, data);

      setState(() {
        _tideData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _getCachedTideData(double lat, double lon) {
    // Round to 4 decimal places for consistent key matching
    final roundedLat = (lat * 10000).round() / 10000;
    final roundedLon = (lon * 10000).round() / 10000;
    final locationKey = '${roundedLat}_${roundedLon}';

    debugPrint(
      '🔍 Cache lookup for key: $locationKey (lat: $lat -> $roundedLat, lon: $lon -> $roundedLon)',
    );

    // Use the unique index to directly get the cache
    final cache = isar.tideCaches.getByLocationKeySync(locationKey);

    debugPrint(
      '📦 Cache result: ${cache != null ? "Found (cached at ${cache.cachedAt})" : "Not found"}',
    );

    if (cache == null) {
      debugPrint('❌ No cache found for $locationKey');
      return null;
    }

    debugPrint('✓ Cache found! Expires at: ${cache.expiresAt}');

    // Check if cache is expired (older than 24 hours)
    if (cache.expiresAt != null && DateTime.now().isAfter(cache.expiresAt!)) {
      debugPrint('⏰ Cache expired, deleting...');
      // Delete expired cache
      isar.writeTxnSync(() {
        isar.tideCaches.deleteSync(cache.id);
      });
      return null;
    }

    // Return cached data
    if (cache.cachedDataJson != null) {
      debugPrint('✓ Returning cached data');
      return jsonDecode(cache.cachedDataJson!) as Map<String, dynamic>;
    }

    debugPrint('❌ Cache found but no JSON data');
    return null;
  }

  void _cacheTideData(double lat, double lon, Map<String, dynamic> data) {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));
    // Round to 4 decimal places for consistent key matching
    final roundedLat = (lat * 10000).round() / 10000;
    final roundedLon = (lon * 10000).round() / 10000;
    final locationKey = '${roundedLat}_${roundedLon}';

    debugPrint(
      '💾 Caching tide data with key: $locationKey, expires: $expiresAt',
    );

    try {
      // Use putByLocationKeySync which automatically replaces existing entries
      final id = isar.writeTxnSync(() {
        final tideCache = TideCache(
          locationKey: locationKey,
          lat: roundedLat,
          lon: roundedLon,
          cachedDataJson: jsonEncode(data),
          cachedAt: now,
          expiresAt: expiresAt,
        );

        return isar.tideCaches.putByLocationKeySync(tideCache);
      });

      debugPrint('💾 Cache written with ID: $id');

      // Verify the cache was written (must be AFTER transaction completes)
      final ourCache = isar.tideCaches.getByLocationKeySync(locationKey);
      if (ourCache != null) {
        debugPrint('✓ Verified: Cache entry exists with key $locationKey');
      } else {
        debugPrint('❌ ERROR: Cache was written but cannot be found!');
      }
    } catch (e) {
      debugPrint('❌ ERROR caching tide data: $e');
    }
  }

  String _getDatumDisplayText() {
    // Environment Agency doesn't support datum selection
    if (!settings.useDummyTides &&
        settings.tidesSource == 'environment_agency') {
      return 'above chart datum';
    }

    // UK Tidal API uses LAT (Lowest Astronomical Tide)
    if (!settings.useDummyTides && settings.tidesSource == 'uk_tidal_api') {
      return 'above LAT (Lowest Astronomical Tide)';
    }

    // Stormglass supports datum selection
    switch (settings.tideDatum) {
      case 'mllw':
        return 'relative to MLLW';
      case 'mlw':
        return 'relative to MLW';
      case 'msl':
        return 'relative to MSL';
      case 'mhw':
        return 'relative to MHW';
      case 'mhhw':
        return 'relative to MHHW';
      default:
        return 'relative to MLLW';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUkTidalApi = settings.tidesSource == 'uk_tidal_api';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tides'),
        centerTitle: true,
        actions: [
          if (!isUkTidalApi) ...[
            IconButton(
              icon: const Icon(LucideIcons.navigation),
              onPressed: _useCurrentLocation,
              tooltip: 'Use Current Location',
            ),
            IconButton(
              icon: const Icon(LucideIcons.mapPin),
              onPressed: _showLocationPicker,
              tooltip: 'Select Location',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(LucideIcons.list),
              onPressed: _showStationBrowser,
              tooltip: 'Browse Stations',
            ),
            IconButton(
              icon: const Icon(LucideIcons.mapPin),
              onPressed: _showSavedStationPicker,
              tooltip: 'Saved Stations',
            ),
          ],
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _fetchTideData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tideData == null
          ? _buildNoStationView()
          : _buildTideView(),
      floatingActionButton: isUkTidalApi
          ? null
          : FloatingActionButton(
              onPressed: _showAddLocationDialog,
              child: const Icon(LucideIcons.plus),
            ),
    );
  }

  Widget _buildNoStationView() {
    if (settings.tidesSource != 'uk_tidal_api') {
      return _buildErrorView();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.waves,
            size: 64,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('No Station Selected', style: context.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Browse and select a tide station to view data',
            style: context.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _showStationBrowser,
            icon: const Icon(LucideIcons.list),
            label: const Text('Browse Stations'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
            'Unable to load tide data',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchTideData,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildTideView() {
    final isEnvironmentAgency =
        !settings.useDummyTides && settings.tidesSource == 'environment_agency';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDataSourceWarning(),
        const SizedBox(height: 16),
        _buildLocationCard(),
        const SizedBox(height: 16),
        _buildCurrentTideCard(),
        if (!isEnvironmentAgency) ...[
          const SizedBox(height: 16),
          _buildNextTidesCard(),
          const SizedBox(height: 16),
          _buildTideChartCard(),
        ],
      ],
    );
  }

  Widget _buildDataSourceWarning() {
    // Don't show warning if using real data from any source
    if (!settings.useDummyTides) {
      // Environment Agency doesn't need an API key
      if (settings.tidesSource == 'environment_agency') {
        return const SizedBox.shrink();
      }
      // UK Tidal API uses Discovery API key
      if (settings.tidesSource == 'uk_tidal_api') {
        if (settings.tidesDiscoveryApiKey != null &&
            settings.tidesDiscoveryApiKey!.isNotEmpty) {
          return const SizedBox.shrink();
        }
      }
      // Stormglass needs an API key
      if (settings.tidesApiKey != null && settings.tidesApiKey!.isNotEmpty) {
        return const SizedBox.shrink();
      }
    }

    return Card(
      color: context.theme.colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 20,
              color: context.theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo Data Only',
                    style: context.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.tidesSource == 'environment_agency'
                        ? 'UK Environment Agency selected but using demo data. Check your location is in UK waters.'
                        : 'Enable real tide data in Settings > Tides',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onErrorContainer,
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

  Widget _buildLocationCard() {
    final showEnvAgencyNote =
        !settings.useDummyTides && settings.tidesSource == 'environment_agency';
    final isUkTidalApi = settings.tidesSource == 'uk_tidal_api';
    final stationName = _tideData?['station']?['name'] as String?;

    String displayName;
    String displayCoords;

    if (isUkTidalApi && _selectedStation != null) {
      displayName = _selectedStation!.name;
      displayCoords =
          '${_selectedStation!.lat.toStringAsFixed(4)}, ${_selectedStation!.lon.toStringAsFixed(4)}';
    } else {
      displayName = _selectedLocation?.name ?? 'Unknown Location';
      displayCoords =
          '${_selectedLocation?.lat?.toStringAsFixed(4)}, ${_selectedLocation?.lon?.toStringAsFixed(4)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.waves,
                    color: context.theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayCoords,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (stationName != null &&
                          stationName != 'Nearby Station' &&
                          stationName != 'Unknown Station') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              LucideIcons.radio,
                              size: 12,
                              color: context.theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Station: $stationName',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context
                                      .theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (showEnvAgencyNote) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.secondaryContainer
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 16,
                      color: context.theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UK Environment Agency provides real-time water levels only. Predictions use interpolated data.',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.theme.colorScheme.onSecondaryContainer,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTideCard() {
    final currentHeight = _tidesAPI.getCurrentTideHeight(_tideData!);
    final nextTideInfo = _tidesAPI.getNextTideInfo(_tideData!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.activity,
                  color: context.theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Tide',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Height',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentHeight.toStringAsFixed(2)} m',
                  style: context.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDatumDisplayText(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 16,
                        color: context.theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          nextTideInfo,
                          style: context.textTheme.bodySmall?.copyWith(
                            color:
                                context.theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextTidesCard() {
    final extremes = _tideData!['extremes'] as List<dynamic>;
    final now = DateTime.now();
    final upcomingTides = extremes
        .where((e) => DateTime.parse(e['date'] as String).isAfter(now))
        .take(6)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.chartLine,
                  color: context.theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Tides',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...upcomingTides.map((tide) => _buildTideItem(tide)),
          ],
        ),
      ),
    );
  }

  Widget _buildTideItem(Map<String, dynamic> tide) {
    final time = DateTime.parse(tide['date'] as String);
    final type = tide['type'] as String;
    final height = (tide['height'] as num).toStringAsFixed(2);
    final isHigh = type == 'High';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHigh
            ? context.theme.colorScheme.primaryContainer.withOpacity(0.3)
            : context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHigh
              ? context.theme.colorScheme.primary.withOpacity(0.3)
              : context.theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHigh ? LucideIcons.arrowUp : LucideIcons.arrowDown,
            color: isHigh
                ? context.theme.colorScheme.primary
                : context.theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type Tide',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM d • HH:mm').format(time),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$height m',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isHigh ? context.theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTideChartCard() {
    final heights = _tideData!['heights'] as List<dynamic>;

    if (heights.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No tide height data available',
              style: context.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final maxHeight = heights
        .map((h) => h['height'] as num)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final minHeight = heights
        .map((h) => h['height'] as num)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.chartLine,
                  color: context.theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tide Chart (24 hours)',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: Size.infinite,
                painter: TideChartPainter(
                  heights: heights.take(24).toList(),
                  maxHeight: maxHeight,
                  minHeight: minHeight,
                  primaryColor: context.theme.colorScheme.primary,
                  surfaceColor:
                      context.theme.colorScheme.surfaceContainerHighest,
                  textColor: context.theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _useCurrentLocation() {
    setState(() {
      final lat = settings.location ? locationCache.lat : 51.5074;
      final lon = settings.location ? locationCache.lon : -0.1278;

      _selectedLocation = TideLocation(
        name: 'Current Location',
        lat: lat,
        lon: lon,
        isPrimary: false,
      );
    });
    _fetchTideData();
  }

  void _showLocationPicker() {
    final locations = isar.tideLocations.where().findAllSync();

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Location', style: context.textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.navigation),
              title: const Text('Current Location'),
              onTap: () {
                Navigator.pop(context);
                _useCurrentLocation();
              },
            ),
            if (locations.isNotEmpty) const Divider(),
            if (locations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No saved locations'),
                ),
              )
            else
              ...locations.map(
                (location) => ListTile(
                  leading: Icon(
                    location.isPrimary ? LucideIcons.star : LucideIcons.mapPin,
                    color: location.isPrimary ? Colors.amber : null,
                  ),
                  title: Text(location.name ?? 'Unknown'),
                  subtitle: Text(
                    '${location.lat?.toStringAsFixed(4)}, ${location.lon?.toStringAsFixed(4)}',
                  ),
                  selected: location.id == _selectedLocation?.id,
                  onTap: () {
                    setState(() => _selectedLocation = location);
                    _fetchTideData();
                    Navigator.pop(context);
                  },
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
                            final allLocations = isar.tideLocations
                                .where()
                                .findAllSync();
                            for (var loc in allLocations) {
                              if (loc.isPrimary) {
                                loc.isPrimary = false;
                                isar.tideLocations.putSync(loc);
                              }
                            }
                            // Set this location as primary
                            if (!location.isPrimary) {
                              location.isPrimary = true;
                              isar.tideLocations.putSync(location);
                            }
                          });
                          Navigator.pop(context);
                          _loadPrimaryLocation();
                        },
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () {
                          isar.writeTxnSync(
                            () => isar.tideLocations.deleteSync(location.id),
                          );
                          Navigator.pop(context);
                          _loadPrimaryLocation();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Tide Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Location Name',
                    prefixIcon: const Icon(LucideIcons.mapPin),
                    suffixIcon: IconButton(
                      icon: isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.search),
                      onPressed: isSearching
                          ? null
                          : () async {
                              final query = nameController.text.trim();
                              if (query.isEmpty) return;

                              setDialogState(() => isSearching = true);
                              try {
                                final locations = await locationFromAddress(
                                  query,
                                );
                                if (locations.isNotEmpty) {
                                  final location = locations.first;
                                  latController.text = location.latitude
                                      .toStringAsFixed(6);
                                  lonController.text = location.longitude
                                      .toStringAsFixed(6);
                                  setDialogState(() {});
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Location not found'),
                                      ),
                                    );
                                  }
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
                  'Tip: Enter a location name (e.g., "Tarn Point UK") and tap search',
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

                if (name.isEmpty || lat == null || lon == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill in all fields with valid values',
                      ),
                    ),
                  );
                  return;
                }

                final location = TideLocation()
                  ..name = name
                  ..lat = lat
                  ..lon = lon
                  ..isPrimary = false
                  ..lastUpdated = DateTime.now();

                isar.writeTxnSync(() => isar.tideLocations.putSync(location));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added location: $name')),
                  );
                  _loadPrimaryLocation();
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStationBrowser() async {
    if (settings.tidesDiscoveryApiKey == null ||
        settings.tidesDiscoveryApiKey!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your UK Tidal API key in Settings > Tides'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final stations = await _tidesAPI.getUkTidalDiscoveryStations(
      settings.tidesDiscoveryApiKey,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (stations.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No stations available or invalid API key'),
        ),
      );
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredStations = searchQuery.isEmpty
                ? stations
                : stations.where((station) {
                    final name =
                        (station['name'] as String?)?.toLowerCase() ?? '';
                    final country =
                        (station['country'] as String?)?.toLowerCase() ?? '';
                    final query = searchQuery.toLowerCase();
                    return name.contains(query) || country.contains(query);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Browse Stations (${filteredStations.length})',
                                style: context.textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search stations...',
                            prefixIcon: const Icon(LucideIcons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filteredStations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.searchX,
                                  size: 48,
                                  color: context
                                      .theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No stations found',
                                  style: context.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filteredStations.length,
                            itemBuilder: (context, index) {
                              final station = filteredStations[index];
                              final stationId = station['id'] as String?;
                              final name = station['name'] as String?;
                              final country = station['country'] as String?;
                              final lat = (station['latitude'] as num?)
                                  ?.toDouble();
                              final lon = (station['longitude'] as num?)
                                  ?.toDouble();

                              if (stationId == null ||
                                  name == null ||
                                  lat == null ||
                                  lon == null) {
                                return const SizedBox.shrink();
                              }

                              // Check if this station is already saved
                              final isSaved =
                                  isar.savedTideStations
                                      .filter()
                                      .stationIdEqualTo(stationId)
                                      .findFirstSync() !=
                                  null;

                              return ListTile(
                                leading: Icon(
                                  isSaved
                                      ? LucideIcons.star
                                      : LucideIcons.waves,
                                  color: isSaved ? Colors.amber : null,
                                ),
                                title: Text(name),
                                subtitle: Text(
                                  '${country ?? 'Unknown'} • ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
                                ),
                                trailing: isSaved
                                    ? const Icon(
                                        LucideIcons.check,
                                        color: Colors.green,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  _saveAndSelectStation(
                                    stationId,
                                    name,
                                    lat,
                                    lon,
                                    country,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _saveAndSelectStation(
    String stationId,
    String name,
    double lat,
    double lon,
    String? country,
  ) {
    // Check if already saved
    final existing = isar.savedTideStations
        .filter()
        .stationIdEqualTo(stationId)
        .findFirstSync();

    if (existing != null) {
      // Already saved, just select it
      setState(() {
        _selectedStation = existing;
      });
      _fetchTideData();
      return;
    }

    // Save new station
    final station = SavedTideStation(
      stationId: stationId,
      name: name,
      lat: lat,
      lon: lon,
      country: country,
      isPrimary: false,
    );

    isar.writeTxnSync(() => isar.savedTideStations.putSync(station));

    setState(() {
      _selectedStation = station;
    });
    _fetchTideData();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved and selected: $name')));
  }

  void _showSavedStationPicker() {
    final stations = isar.savedTideStations.where().findAllSync();

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Stations', style: context.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (stations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No saved stations'),
                ),
              )
            else
              ...stations.map(
                (station) => ListTile(
                  leading: Icon(
                    station.isPrimary ? LucideIcons.star : LucideIcons.waves,
                    color: station.isPrimary ? Colors.amber : null,
                  ),
                  title: Text(station.name),
                  subtitle: Text(
                    '${station.country ?? 'Unknown'} • ${station.lat.toStringAsFixed(4)}, ${station.lon.toStringAsFixed(4)}',
                  ),
                  selected: station.stationId == _selectedStation?.stationId,
                  onTap: () {
                    setState(() => _selectedStation = station);
                    _fetchTideData();
                    Navigator.pop(context);
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          station.isPrimary
                              ? LucideIcons.starOff
                              : LucideIcons.star,
                        ),
                        tooltip: station.isPrimary
                            ? 'Remove as default'
                            : 'Set as default',
                        onPressed: () {
                          isar.writeTxnSync(() {
                            // Clear all primary flags
                            final allStations = isar.savedTideStations
                                .where()
                                .findAllSync();
                            for (var s in allStations) {
                              if (s.isPrimary) {
                                s.isPrimary = false;
                                isar.savedTideStations.putSync(s);
                              }
                            }
                            // Set this station as primary
                            if (!station.isPrimary) {
                              station.isPrimary = true;
                              isar.savedTideStations.putSync(station);
                            }
                          });
                          Navigator.pop(context);
                          _loadPrimaryLocation();
                        },
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () {
                          isar.writeTxnSync(
                            () => isar.savedTideStations.deleteSync(station.id),
                          );
                          Navigator.pop(context);
                          _loadPrimaryLocation();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TideChartPainter extends CustomPainter {
  final List<dynamic> heights;
  final double maxHeight;
  final double minHeight;
  final Color primaryColor;
  final Color surfaceColor;
  final Color textColor;

  TideChartPainter({
    required this.heights,
    required this.maxHeight,
    required this.minHeight,
    required this.primaryColor,
    required this.surfaceColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    // Define margins for axis labels
    const leftMargin = 40.0;
    const bottomMargin = 30.0;
    const rightMargin = 10.0;
    const topMargin = 10.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    final paint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final axisPaint = Paint()
      ..color = textColor.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final path = Path();
    final fillPath = Path();

    final heightRange = maxHeight - minHeight;
    final xStep = chartWidth / (heights.length - 1);

    // Draw Y-axis grid lines and labels
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    // Draw 5 horizontal grid lines with labels
    for (int i = 0; i <= 4; i++) {
      final ratio = i / 4;
      final y = topMargin + (chartHeight * (1 - ratio));
      final heightValue = minHeight + (heightRange * ratio);

      // Draw grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + chartWidth, y),
        axisPaint,
      );

      // Draw Y-axis label
      textPainter.text = TextSpan(
        text: '${heightValue.toStringAsFixed(1)}m',
        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Draw the tide curve
    for (int i = 0; i < heights.length; i++) {
      final height = heights[i]['height'] as num;
      final normalizedHeight = (height - minHeight) / heightRange;
      final y = topMargin + (chartHeight * (1 - normalizedHeight));
      final x = leftMargin + (i * xStep);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topMargin + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(leftMargin + chartWidth, topMargin + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw X-axis labels (time)
    final timeLabels = [0, 6, 12, 18, 24];
    for (final hour in timeLabels) {
      if (hour >= heights.length) continue;

      final x = leftMargin + (hour * xStep);
      final y = topMargin + chartHeight;

      // Draw tick mark
      canvas.drawLine(Offset(x, y), Offset(x, y + 5), axisPaint);

      // Draw time label
      textPainter.text = TextSpan(
        text: '${hour}h',
        style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y + 8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
