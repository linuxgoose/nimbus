import 'package:isar_community/isar.dart';

part 'db.g.dart';

@collection
class Settings {
  Id id = Isar.autoIncrement;
  int schemaVersion = 1; // Track schema version for migrations
  bool onboard = false;
  String? theme = 'system';
  bool location = false;
  bool notifications = false;
  bool materialColor = false;
  bool amoledTheme = false;
  bool roundDegree = false;
  bool largeElement = false;
  bool hideMap = false;
  bool hideTides = false;
  bool hideAqi = false;
  bool useDummyTides = true;
  String tidesSource =
      'environment_agency'; // stormglass, environment_agency, uk_tidal_api
  String? tidesApiKey;
  String? tidesDiscoveryApiKey;
  String tideDatum = 'mllw'; // mllw, mlw, msl, mhw, mhhw
  bool hideElevation = false;
  bool useDummyElevation = true;
  String elevationSource =
      'open_meteo'; // open_meteo, nimbusmeteo, open_elevation
  String? elevationApiKey;
  bool hideAurora = false;
  bool auroraNotifications = false;
  double auroraNotificationThreshold = 5.0; // Kp index threshold
  bool hideEarthEvents = false;
  bool hideFlood = false;
  bool floodNotifications = false;
  double floodRadiusKm = 100.0; // Radius to check for flood warnings
  bool weatherAlertNotifications = false;
  String weatherAlertMinSeverity = 'moderate'; // all, moderate, severe, extreme
  bool hideAgriculture = false;
  bool hideMarine = false;
  bool hideHiking = false;
  bool rainNotifications = false;
  double rainNotificationThreshold = 1.0; // mm of rain threshold
  String? widgetBackgroundColor;
  String? widgetTextColor;
  String degrees = 'celsius';
  String pressure = 'hPa';
  String timeformat = '24';
  String aqiIndex = 'daqi';
  String measurements = 'imperial';
  String wind = 'mph';
  bool showDummyAlerts = false;
  String alertMinSeverity = 'all'; // all, moderate, severe, extreme
  bool showAlertsOnMainPage = true;
  bool showAlertsOnMap = true;
  String weatherDataSource = 'openmeteo'; // openmeteo, metno, hybrid
  bool preferMetNoInHybrid =
      false; // Override Nordic region detection in hybrid mode
  bool hideRainForecast = false; // Hide 6-hour rain forecast chart
  bool useCustomOpenMeteoEndpoint = false; // Use custom Open-Meteo server
  String?
  customOpenMeteoUrl; // Custom Open-Meteo API base URL (e.g., https://nimbusmeteo.linuxgoose.com)
  String? customAirQualityUrl; // Custom Air Quality API URL
  String? customMarineUrl; // Custom Marine API URL
  String? customGeocodingUrl; // Custom Geocoding API URL
  String geocodingSource = 'openmeteo'; // openmeteo, nimbusmeteo, custom
  String nowTileMetric1 = 'humidity'; // First metric to show in now tile
  String nowTileMetric2 = 'wind'; // Second metric to show in now tile
  String? language;
  int? timeRange;
  String? timeStart;
  String? timeEnd;
}

@collection
class TideStation {
  Id id = Isar.autoIncrement;
  String? stationId; // UK Tidal API station ID
  String? name;
  double? lat;
  double? lon;
  String? country;
  bool isSaved = false;

  TideStation({
    this.stationId,
    this.name,
    this.lat,
    this.lon,
    this.country,
    this.isSaved = false,
  });
}

@collection
class SavedTideStation {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String stationId = ''; // UK Tidal API station ID

  String name = '';
  double lat = 0.0;
  double lon = 0.0;
  String? country;
  bool isPrimary = false;
  DateTime savedAt = DateTime.now();

  SavedTideStation({
    required this.stationId,
    required this.name,
    required this.lat,
    required this.lon,
    this.country,
    this.isPrimary = false,
  });
}

@collection
class AlertHistory {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String eventKey = ''; // Composite key: lat_lon_timestamp_event

  double lat;
  double lon;
  DateTime timestamp;

  String event;
  String? description;
  String severity; // extreme, severe, moderate, minor
  String? boundariesJson; // Store boundaries as JSON string
  DateTime? startTime;
  DateTime? endTime;

  AlertHistory({
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.event,
    this.description,
    required this.severity,
    this.boundariesJson,
    this.startTime,
    this.endTime,
  });
}

@collection
class MainWeatherCache {
  Id id = Isar.autoIncrement;
  List<String>? time;
  List<int?>? weathercode;
  List<double?>? temperature2M;
  List<double?>? apparentTemperature;
  List<int?>? relativehumidity2M;
  List<double?>? precipitation;
  List<double?>? rain;
  List<double?>? surfacePressure;
  List<double?>? visibility;
  List<double?>? evapotranspiration;
  List<double?>? windspeed10M;
  List<int?>? winddirection10M;
  List<double?>? windgusts10M;
  List<int?>? cloudcover;
  List<double?>? uvIndex;
  List<double?>? dewpoint2M;
  List<int?>? precipitationProbability;
  List<double?>? shortwaveRadiation;
  List<DateTime>? timeDaily;
  List<int?>? weathercodeDaily;
  List<double?>? temperature2MMax;
  List<double?>? temperature2MMin;
  List<double?>? apparentTemperatureMax;
  List<double?>? apparentTemperatureMin;
  List<String>? sunrise;
  List<String>? sunset;
  List<double?>? precipitationSum;
  List<int?>? precipitationProbabilityMax;
  List<double?>? windspeed10MMax;
  List<double?>? windgusts10MMax;
  List<double?>? uvIndexMax;
  List<double?>? rainSum;
  List<int?>? winddirection10MDominant;
  String? timezone;
  DateTime? timestamp;

  MainWeatherCache({
    this.time,
    this.temperature2M,
    this.relativehumidity2M,
    this.apparentTemperature,
    this.precipitation,
    this.rain,
    this.weathercode,
    this.surfacePressure,
    this.visibility,
    this.evapotranspiration,
    this.windspeed10M,
    this.winddirection10M,
    this.windgusts10M,
    this.cloudcover,
    this.uvIndex,
    this.dewpoint2M,
    this.precipitationProbability,
    this.shortwaveRadiation,
    this.timeDaily,
    this.weathercodeDaily,
    this.temperature2MMax,
    this.temperature2MMin,
    this.apparentTemperatureMax,
    this.apparentTemperatureMin,
    this.sunrise,
    this.sunset,
    this.precipitationSum,
    this.precipitationProbabilityMax,
    this.windspeed10MMax,
    this.windgusts10MMax,
    this.uvIndexMax,
    this.rainSum,
    this.winddirection10MDominant,
    this.timezone,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'weathercode': weathercode,
    'temperature2M': temperature2M,
    'apparentTemperature': apparentTemperature,
    'relativehumidity2M': relativehumidity2M,
    'precipitation': precipitation,
    'rain': rain,
    'surfacePressure': surfacePressure,
    'visibility': visibility,
    'evapotranspiration': evapotranspiration,
    'windspeed10M': windspeed10M,
    'winddirection10M': winddirection10M,
    'windgusts10M': windgusts10M,
    'cloudcover': cloudcover,
    'uvIndex': uvIndex,
    'dewpoint2M': dewpoint2M,
    'precipitationProbability': precipitationProbability,
    'shortwaveRadiation': shortwaveRadiation,
    'timeDaily': timeDaily,
    'weathercodeDaily': weathercodeDaily,
    'temperature2MMax': temperature2MMax,
    'temperature2MMin': temperature2MMin,
    'apparentTemperatureMax': apparentTemperatureMax,
    'apparentTemperatureMin': apparentTemperatureMin,
    'sunrise': sunrise,
    'sunset': sunset,
    'precipitationSum': precipitationSum,
    'precipitationProbabilityMax': precipitationProbabilityMax,
    'windspeed10MMax': windspeed10MMax,
    'windgusts10MMax': windgusts10MMax,
    'uvIndexMax': uvIndexMax,
    'rainSum': rainSum,
    'winddirection10MDominant': winddirection10MDominant,
    'timezone': timezone,
    'timestamp': timestamp,
  };
}

@collection
class LocationCache {
  Id id = Isar.autoIncrement;
  double? lat;
  double? lon;
  String? city;
  String? district;
  String? country;

  LocationCache({this.lat, this.lon, this.city, this.district, this.country});

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lon': lon,
    'city': city,
    'district': district,
    'country': country,
  };
}

@collection
class WeatherCard {
  Id id = Isar.autoIncrement;
  List<String>? time;
  List<int?>? weathercode;
  List<double?>? temperature2M;
  List<double?>? apparentTemperature;
  List<int?>? relativehumidity2M;
  List<double?>? precipitation;
  List<double?>? rain;
  List<double?>? surfacePressure;
  List<double?>? visibility;
  List<double?>? evapotranspiration;
  List<double?>? windspeed10M;
  List<int?>? winddirection10M;
  List<double?>? windgusts10M;
  List<int?>? cloudcover;
  List<double?>? uvIndex;
  List<double?>? dewpoint2M;
  List<int?>? precipitationProbability;
  List<double?>? shortwaveRadiation;
  List<DateTime>? timeDaily;
  List<int?>? weathercodeDaily;
  List<double?>? temperature2MMax;
  List<double?>? temperature2MMin;
  List<double?>? apparentTemperatureMax;
  List<double?>? apparentTemperatureMin;
  List<String>? sunrise;
  List<String>? sunset;
  List<double?>? precipitationSum;
  List<int?>? precipitationProbabilityMax;
  List<double?>? windspeed10MMax;
  List<double?>? windgusts10MMax;
  List<double?>? uvIndexMax;
  List<double?>? rainSum;
  List<int?>? winddirection10MDominant;
  double? lat;
  double? lon;
  String? city;
  String? district;
  String? timezone;
  DateTime? timestamp;
  int? index;

  WeatherCard({
    this.time,
    this.temperature2M,
    this.relativehumidity2M,
    this.apparentTemperature,
    this.precipitation,
    this.rain,
    this.weathercode,
    this.surfacePressure,
    this.visibility,
    this.evapotranspiration,
    this.windspeed10M,
    this.winddirection10M,
    this.windgusts10M,
    this.cloudcover,
    this.uvIndex,
    this.dewpoint2M,
    this.precipitationProbability,
    this.shortwaveRadiation,
    this.timeDaily,
    this.weathercodeDaily,
    this.temperature2MMax,
    this.temperature2MMin,
    this.apparentTemperatureMax,
    this.apparentTemperatureMin,
    this.sunrise,
    this.sunset,
    this.precipitationSum,
    this.precipitationProbabilityMax,
    this.windspeed10MMax,
    this.windgusts10MMax,
    this.uvIndexMax,
    this.rainSum,
    this.winddirection10MDominant,
    this.lat,
    this.lon,
    this.city,
    this.district,
    this.timezone,
    this.timestamp,
    this.index,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'weathercode': weathercode,
    'temperature2M': temperature2M,
    'apparentTemperature': apparentTemperature,
    'relativehumidity2M': relativehumidity2M,
    'precipitation': precipitation,
    'rain': rain,
    'surfacePressure': surfacePressure,
    'visibility': visibility,
    'evapotranspiration': evapotranspiration,
    'windspeed10M': windspeed10M,
    'winddirection10M': winddirection10M,
    'windgusts10M': windgusts10M,
    'cloudcover': cloudcover,
    'uvIndex': uvIndex,
    'dewpoint2M': dewpoint2M,
    'precipitationProbability': precipitationProbability,
    'shortwaveRadiation': shortwaveRadiation,
    'timeDaily': timeDaily,
    'weathercodeDaily': weathercodeDaily,
    'temperature2MMax': temperature2MMax,
    'temperature2MMin': temperature2MMin,
    'apparentTemperatureMax': apparentTemperatureMax,
    'apparentTemperatureMin': apparentTemperatureMin,
    'sunrise': sunrise,
    'sunset': sunset,
    'precipitationSum': precipitationSum,
    'precipitationProbabilityMax': precipitationProbabilityMax,
    'windspeed10MMax': windspeed10MMax,
    'windgusts10MMax': windgusts10MMax,
    'uvIndexMax': uvIndexMax,
    'rainSum': rainSum,
    'winddirection10MDominant': winddirection10MDominant,
    'timezone': timezone,
    'timestamp': timestamp,
    'lat': lat,
    'lon': lon,
    'city': city,
    'district': district,
    'index': index,
  };

  factory WeatherCard.fromJson(Map<String, dynamic> json) {
    return WeatherCard(
      time: List<String>.from(json['time'] ?? []),
      weathercode: List<int?>.from(json['weathercode'] ?? []),
      temperature2M: List<double?>.from(json['temperature2M'] ?? []),
      apparentTemperature: List<double?>.from(
        json['apparentTemperature'] ?? [],
      ),
      relativehumidity2M: List<int?>.from(json['relativehumidity2M'] ?? []),
      precipitation: List<double?>.from(json['precipitation'] ?? []),
      rain: List<double?>.from(json['rain'] ?? []),
      surfacePressure: List<double?>.from(json['surfacePressure'] ?? []),
      visibility: List<double?>.from(json['visibility'] ?? []),
      evapotranspiration: List<double?>.from(json['evapotranspiration'] ?? []),
      windspeed10M: List<double?>.from(json['windspeed10M'] ?? []),
      winddirection10M: List<int?>.from(json['winddirection10M'] ?? []),
      windgusts10M: List<double?>.from(json['windgusts10M'] ?? []),
      cloudcover: List<int?>.from(json['cloudcover'] ?? []),
      uvIndex: List<double?>.from(json['uvIndex'] ?? []),
      dewpoint2M: List<double?>.from(json['dewpoint2M'] ?? []),
      precipitationProbability: List<int?>.from(
        json['precipitationProbability'] ?? [],
      ),
      shortwaveRadiation: List<double?>.from(json['shortwaveRadiation'] ?? []),
      timeDaily: List<DateTime>.from(json['timeDaily'] ?? []),
      weathercodeDaily: List<int?>.from(json['weathercodeDaily'] ?? []),
      temperature2MMax: List<double?>.from(json['temperature2MMax'] ?? []),
      temperature2MMin: List<double?>.from(json['temperature2MMin'] ?? []),
      apparentTemperatureMax: List<double?>.from(
        json['apparentTemperatureMax'] ?? [],
      ),
      apparentTemperatureMin: List<double?>.from(
        json['apparentTemperatureMin'] ?? [],
      ),
      windspeed10MMax: List<double?>.from(json['windspeed10MMax'] ?? []),
      windgusts10MMax: List<double?>.from(json['windgusts10MMax'] ?? []),
      uvIndexMax: List<double?>.from(json['uvIndexMax'] ?? []),
      rainSum: List<double?>.from(json['rainSum'] ?? []),
      winddirection10MDominant: List<int?>.from(
        json['winddirection10MDominant'] ?? [],
      ),
      precipitationSum: List<double?>.from(json['precipitationSum'] ?? []),
      precipitationProbabilityMax: List<int?>.from(
        json['precipitationProbabilityMax'] ?? [],
      ),
      sunrise: List<String>.from(json['sunrise'] ?? []),
      sunset: List<String>.from(json['sunset'] ?? []),
      lat: json['lat'],
      lon: json['lon'],
      city: json['city'],
      district: json['district'],
      timezone: json['timezone'],
      timestamp: json['timestamp'],
      index: json['index'],
    );
  }
}

@collection
class TideLocation {
  Id id = Isar.autoIncrement;
  String? name;
  double? lat;
  double? lon;
  bool isPrimary = false;
  DateTime? lastUpdated;

  TideLocation({
    this.name,
    this.lat,
    this.lon,
    this.isPrimary = false,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lon': lon,
    'isPrimary': isPrimary,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory TideLocation.fromJson(Map<String, dynamic> json) => TideLocation(
    name: json['name'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    isPrimary: json['isPrimary'] as bool? ?? false,
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.parse(json['lastUpdated'] as String)
        : null,
  );
}

@collection
class ElevationLocation {
  Id id = Isar.autoIncrement;
  String? name;
  double? lat;
  double? lon;
  bool isPrimary = false;
  DateTime? lastUpdated;

  ElevationLocation({
    this.name,
    this.lat,
    this.lon,
    this.isPrimary = false,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lon': lon,
    'isPrimary': isPrimary,
    'lastUpdated': lastUpdated?.toIso8601String(),
  };

  factory ElevationLocation.fromJson(Map<String, dynamic> json) =>
      ElevationLocation(
        name: json['name'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
        isPrimary: json['isPrimary'] as bool? ?? false,
        lastUpdated: json['lastUpdated'] != null
            ? DateTime.parse(json['lastUpdated'] as String)
            : null,
      );
}

@collection
class AuroraCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String locationKey = ''; // Composite key: "lat_lon"

  double? kpIndex;
  String? activityLevel;
  String? timestamp;
  String? ukStatus;
  String? forecastJson; // Store 3-day forecast as JSON string
  DateTime? cachedAt;
  double? latitude;
  double? longitude;

  AuroraCache();

  factory AuroraCache.fromJson(Map<String, dynamic> json) => AuroraCache()
    ..id = json['id'] as int? ?? Isar.autoIncrement
    ..locationKey = json['locationKey'] as String? ?? ''
    ..kpIndex = (json['kpIndex'] as num?)?.toDouble()
    ..activityLevel = json['activityLevel'] as String?
    ..timestamp = json['timestamp'] as String?
    ..ukStatus = json['ukStatus'] as String?
    ..forecastJson = json['forecastJson'] as String?
    ..cachedAt = json['cachedAt'] != null
        ? DateTime.parse(json['cachedAt'] as String)
        : null
    ..latitude = (json['latitude'] as num?)?.toDouble()
    ..longitude = (json['longitude'] as num?)?.toDouble();
}

@collection
class TideCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String locationKey = ''; // Composite key: "lat_lon"
  double? lat;
  double? lon;

  String? cachedDataJson; // Store the entire tide data response as JSON
  DateTime? cachedAt;
  DateTime? expiresAt; // Cache expires after 24 hours

  TideCache({
    required this.locationKey,
    this.lat,
    this.lon,
    this.cachedDataJson,
    this.cachedAt,
    this.expiresAt,
  });
}

@collection
class AqiCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String locationKey = ''; // Composite key: "lat_lon"
  double? lat;
  double? lon;

  String? cachedDataJson; // Store the entire AQI data response as JSON
  DateTime? cachedAt;
  DateTime? expiresAt; // Cache expires after 1 hour

  AqiCache({
    required this.locationKey,
    this.lat,
    this.lon,
    this.cachedDataJson,
    this.cachedAt,
    this.expiresAt,
  });
}

@collection
class RainForecastCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String locationKey = ''; // Composite key: "lat_lon"
  double? lat;
  double? lon;

  List<String>? times; // Array of ISO timestamp strings
  List<double?>? precipitation; // Array of precipitation values in mm
  String? resolution; // '15min' or 'hourly'
  DateTime? cachedAt;
  DateTime? expiresAt; // Cache expires after 30 minutes

  RainForecastCache({
    required this.locationKey,
    this.lat,
    this.lon,
    this.times,
    this.precipitation,
    this.resolution,
    this.cachedAt,
    this.expiresAt,
  });
}

@collection
class ElevationCache {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String locationKey = ''; // Composite key: "lat_lon"
  double? lat;
  double? lon;

  String? cachedDataJson; // Store the entire elevation data response as JSON
  DateTime? cachedAt;
  DateTime? expiresAt; // Cache expires after 7 days (elevation doesn't change)

  ElevationCache({
    required this.locationKey,
    this.lat,
    this.lon,
    this.cachedDataJson,
    this.cachedAt,
    this.expiresAt,
  });
}
