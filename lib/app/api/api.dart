import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nimbus/app/api/city_api.dart';
import 'package:nimbus/app/api/weather_api.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/services/hybrid_weather_service.dart';
import 'package:nimbus/app/services/pirateweather_service.dart';
import 'package:nimbus/app/services/weatherapi_service.dart';
import 'package:nimbus/main.dart';

class WeatherAPI {
  // Base URL updated to exclude the '?' to handle queryParameters cleanly via Dio
  final Dio dio = Dio();
  final Dio dioLocation = Dio();

  WeatherAPI() {
    // Set base URL dynamically on each request instead of in constructor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final baseUrl = _getBaseUrl();
          debugPrint('🔧 Interceptor setting baseUrl: $baseUrl');
          options.baseUrl = baseUrl;
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('📥 Response from: ${response.requestOptions.uri}');
          return handler.next(response);
        },
      ),
    );
  }

  String _getBaseUrl() {
    try {
      // Use Nimbus Meteo if selected as data source
      if (settings.weatherDataSource == 'nimbusmeteo') {
        debugPrint('🌤️ Using Nimbus Meteo endpoint');
        return 'https://nimbusmeteo.linuxgoose.com/v1/forecast';
      }
      // Use custom endpoint if configured
      if (settings.useCustomOpenMeteoEndpoint &&
          settings.customOpenMeteoUrl != null &&
          settings.customOpenMeteoUrl!.isNotEmpty) {
        final customUrl = settings.customOpenMeteoUrl!;
        // Remove trailing slash if present
        final cleanUrl = customUrl.endsWith('/')
            ? customUrl.substring(0, customUrl.length - 1)
            : customUrl;
        debugPrint('🔧 Using custom endpoint: $cleanUrl');
        return '$cleanUrl/v1/forecast';
      }
    } catch (e) {
      debugPrint('⚠️ Error getting base URL, using default Open-Meteo: $e');
    }
    return 'https://api.open-meteo.com/v1/forecast';
  }

  // Added alerts=true for weather warnings
  static const String _weatherParams =
      'hourly=temperature_2m,relativehumidity_2m,apparent_temperature,precipitation,rain,weathercode,surface_pressure,visibility,evapotranspiration,windspeed_10m,winddirection_10m,windgusts_10m,cloudcover,uv_index,dewpoint_2m,precipitation_probability,shortwave_radiation'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,windspeed_10m_max,windgusts_10m_max,uv_index_max,rain_sum,winddirection_10m_dominant'
      '&forecast_days=12&timezone=auto'
      '&alerts=true'; // Required for weather warnings

  String _buildWeatherUrl(double lat, double lon) {
    String url = '?latitude=$lat&longitude=$lon&$_weatherParams';
    if (settings.measurements == 'imperial') {
      url += '&windspeed_unit=mph&precipitation_unit=inch';
    }
    if (settings.degrees == 'fahrenheit') {
      url += '&temperature_unit=fahrenheit';
    }
    return url;
  }

  Future<MainWeatherCache> getWeatherData(double lat, double lon) async {
    // WeatherAPI primary source
    if (settings.weatherDataSource == 'weatherapi') {
      try {
        debugPrint('🌦️ Using WeatherAPI as primary source');
        final waData = await WeatherApiService.getWeatherData(
          lat: lat,
          lon: lon,
        );
        if (waData != null) {
          debugPrint('✅ Using WeatherAPI data');
          final weatherData = WeatherDataApi.fromJson(waData);
          return _mapWeatherDataToCache(weatherData);
        } else {
          debugPrint('⚠️ WeatherAPI returned null, falling back to Open-Meteo');
        }
      } catch (e) {
        debugPrint('❌ WeatherAPI error: $e, falling back to Open-Meteo');
      }
    }

    // Check if we should use PirateWeather
    if (settings.weatherDataSource == 'pirateweather') {
      try {
        debugPrint('🏴‍☠️ Using PirateWeather as primary source');
        final pirateData = await PirateWeatherService.getWeatherData(
          lat: lat,
          lon: lon,
        );

        if (pirateData != null) {
          debugPrint('✅ Using PirateWeather data');
          WeatherDataApi weatherData = WeatherDataApi.fromJson(pirateData);
          return _mapWeatherDataToCache(weatherData);
        } else {
          debugPrint(
            '⚠️ PirateWeather returned null, falling back to Open-Meteo',
          );
        }
      } catch (e) {
        debugPrint('❌ PirateWeather error: $e, falling back to Open-Meteo');
      }
    }

    // Check if we should use hybrid/MET Norway service (but NOT for Nimbus Meteo)
    if ((settings.weatherDataSource == 'metno' ||
            settings.weatherDataSource == 'hybrid') &&
        settings.weatherDataSource != 'nimbusmeteo') {
      try {
        debugPrint('🔀 Checking hybrid weather service for $lat, $lon');
        final hybridData = await HybridWeatherService.getWeatherData(
          lat: lat,
          lon: lon,
        );

        if (hybridData != null) {
          debugPrint('✅ Using hybrid weather data');
          WeatherDataApi weatherData = WeatherDataApi.fromJson(hybridData);
          return _mapWeatherDataToCache(weatherData);
        } else {
          debugPrint(
            '⚠️ Hybrid service returned null, falling back to Open-Meteo',
          );
        }
      } catch (e) {
        debugPrint('❌ Hybrid service error: $e, falling back to Open-Meteo');
      }
    }

    // Use Open-Meteo or Nimbus Meteo (base URL set by interceptor)
    debugPrint('📡 Using ${settings.weatherDataSource} for weather data');
    final String urlWeather = _buildWeatherUrl(lat, lon);
    debugPrint('🌐 Full URL: ${dio.options.baseUrl}$urlWeather');
    try {
      Response response = await dio.get(urlWeather);
      debugPrint('✅ Response received: ${response.statusCode}');
      debugPrint('📦 Data keys: ${response.data?.keys}');

      // Debug hourly data
      if (response.data != null && response.data['hourly'] != null) {
        final hourly = response.data['hourly'];
        debugPrint('📊 Hourly keys: ${hourly.keys}');
        debugPrint(
          '📊 Has relativehumidity_2m: ${hourly.containsKey('relativehumidity_2m')}',
        );
        debugPrint(
          '📊 Has windspeed_10m: ${hourly.containsKey('windspeed_10m')}',
        );
        debugPrint(
          '📊 Has precipitation_probability: ${hourly.containsKey('precipitation_probability')}',
        );
        debugPrint('📊 Has uv_index: ${hourly.containsKey('uv_index')}');
      }

      WeatherDataApi weatherData = WeatherDataApi.fromJson(response.data);

      // Debug parsed data
      debugPrint(
        '📊 Parsed relativehumidity_2m length: ${weatherData.hourly.relativeHumidity2M?.length}',
      );
      debugPrint(
        '📊 Parsed windspeed_10m length: ${weatherData.hourly.windSpeed10M?.length}',
      );
      debugPrint(
        '📊 Parsed precipitation_probability length: ${weatherData.hourly.precipitationProbability?.length}',
      );
      debugPrint(
        '📊 Parsed uv_index length: ${weatherData.hourly.uvIndex?.length}',
      );

      return _mapWeatherDataToCache(weatherData);
    } on DioException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  // Optimized method to fetch ONLY alerts for map rendering
  Future<List<dynamic>> getRawAlerts(double lat, double lon) async {
    // Try hybrid service first for MET Norway official alerts
    if (settings.weatherDataSource == 'metno' ||
        settings.weatherDataSource == 'hybrid') {
      try {
        debugPrint('🚨 Fetching alerts via hybrid service');
        final hybridAlerts = await HybridWeatherService.getWeatherAlerts(
          lat: lat,
          lon: lon,
        );

        if (hybridAlerts.isNotEmpty) {
          debugPrint(
            '✅ Found ${hybridAlerts.length} alerts from hybrid service',
          );
          // Store alerts in history
          _storeAlertsInHistory(hybridAlerts, lat, lon);
          return hybridAlerts;
        }
      } catch (e) {
        debugPrint('❌ Hybrid alert fetch error: $e');
      }
    }

    // Default: Use Open-Meteo alerts
    try {
      final response = await dio.get(
        '',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'models': 'gem_global',
          'alerts': 'true',
          'forecast_days': 1, // Minimize payload for map refresh
        },
      );
      return response.data['alerts'] ?? [];
    } on DioException catch (e) {
      if (kDebugMode) {
        print("Alert Fetch Error: $e");
      }
      return [];
    }
  }

  void _storeAlertsInHistory(List<dynamic> alerts, double lat, double lon) {
    try {
      final timestamp = DateTime.now();

      for (var alert in alerts) {
        final event = alert['event']?.toString() ?? 'Weather Alert';
        final severity = (alert['severity']?.toString() ?? 'moderate')
            .toLowerCase();

        // Create unique key combining location and event
        final eventKey =
            '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}_${timestamp.millisecondsSinceEpoch}_$event';

        final alertHistory = AlertHistory(
          lat: lat,
          lon: lon,
          timestamp: timestamp,
          event: event,
          description: alert['description']?.toString(),
          severity: severity,
        )..eventKey = eventKey;

        isar.writeTxnSync(() {
          isar.alertHistorys.putByEventKeySync(alertHistory);
        });
      }

      debugPrint('💾 Stored ${alerts.length} alerts in history');
    } catch (e) {
      debugPrint('❌ Error storing alerts in history: $e');
    }
  }

  Future<WeatherCard> getWeatherCard(
    double lat,
    double lon,
    String city,
    String district,
    String timezone,
  ) async {
    // Check if we should use hybrid/MET Norway service (but NOT for Nimbus Meteo)
    if ((settings.weatherDataSource == 'metno' ||
            settings.weatherDataSource == 'hybrid') &&
        settings.weatherDataSource != 'nimbusmeteo') {
      try {
        debugPrint('🔀 Checking hybrid weather service for weather card');
        final hybridData = await HybridWeatherService.getWeatherData(
          lat: lat,
          lon: lon,
        );

        if (hybridData != null) {
          debugPrint('✅ Using hybrid weather data for card');
          WeatherDataApi weatherData = WeatherDataApi.fromJson(hybridData);
          return _mapWeatherDataToCard(
            weatherData,
            lat,
            lon,
            city,
            district,
            timezone,
          );
        } else {
          debugPrint(
            '⚠️ Hybrid service returned null, falling back to Open-Meteo',
          );
        }
      } catch (e) {
        debugPrint('❌ Hybrid service error: $e, falling back to Open-Meteo');
      }
    }

    // Default: Use Open-Meteo or Nimbus Meteo
    final String urlWeather = _buildWeatherUrl(lat, lon);
    try {
      Response response = await dio.get(urlWeather);
      WeatherDataApi weatherData = WeatherDataApi.fromJson(response.data);
      return _mapWeatherDataToCard(
        weatherData,
        lat,
        lon,
        city,
        district,
        timezone,
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  Future<Iterable<Result>> getCity(String query, Locale? locale) async {
    String baseGeocodingUrl = 'https://geocoding-api.open-meteo.com';
    bool useNominatim = false;

    // Use selected geocoding source
    if (settings.geocodingSource == 'nimbusmeteo') {
      baseGeocodingUrl = 'https://geocoding.nimbusmeteo.linuxgoose.com';
      useNominatim = true; // Nimbus Meteo uses Nominatim
    } else if (settings.geocodingSource == 'custom' &&
        settings.customGeocodingUrl != null &&
        settings.customGeocodingUrl!.isNotEmpty) {
      baseGeocodingUrl = settings.customGeocodingUrl!;
    }
    // Otherwise use public Open-Meteo API

    try {
      if (useNominatim) {
        // Nominatim API format
        final String url =
            '$baseGeocodingUrl/search?q=$query&format=json&limit=5&addressdetails=1';

        Response response = await dioLocation.get(url);
        if (response.statusCode == 200) {
          final List<dynamic> results = response.data as List<dynamic>;
          return results.map((item) {
            final address = item['address'] ?? {};
            final displayName = item['display_name'] ?? '';

            // Extract city/town name and region
            String cityName =
                address['city'] ??
                address['town'] ??
                address['village'] ??
                address['hamlet'] ??
                displayName.split(',').first;
            String? admin1 =
                address['state'] ?? address['county'] ?? address['region'];
            String? country = address['country'];

            return Result(
              admin1: admin1 ?? '',
              name: cityName,
              latitude: double.tryParse(item['lat'].toString()) ?? 0.0,
              longitude: double.tryParse(item['lon'].toString()) ?? 0.0,
              country: country,
            );
          });
        }
      } else {
        // Open-Meteo API format
        final String url =
            '$baseGeocodingUrl/v1/search?name=$query&count=5&language=${locale?.languageCode}&format=json';

        Response response = await dioLocation.get(url);
        if (response.statusCode == 200) {
          CityApi cityData = CityApi.fromJson(response.data);
          return cityData.results.map(
            (e) => Result(
              admin1: e.admin1,
              name: e.name,
              latitude: e.latitude,
              longitude: e.longitude,
              country: e.country,
            ),
          );
        }
      }

      throw Exception('Failed to load suggestions');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('⚠️ Geocoding error: ${e.message}');
      }
      // Return empty results on error instead of crashing
      return [];
    }
  }

  MainWeatherCache _mapWeatherDataToCache(WeatherDataApi weatherData) {
    debugPrint(
      '📊 _mapWeatherDataToCache - precipitationProbability from API: ${weatherData.hourly.precipitationProbability?.length}',
    );
    debugPrint(
      '📊 _mapWeatherDataToCache - precipitationProbability values: ${weatherData.hourly.precipitationProbability?.take(5)}',
    );

    return MainWeatherCache(
      time: weatherData.hourly.time,
      temperature2M: weatherData.hourly.temperature2M,
      relativehumidity2M: weatherData.hourly.relativeHumidity2M,
      apparentTemperature: weatherData.hourly.apparentTemperature,
      precipitation: weatherData.hourly.precipitation,
      rain: weatherData.hourly.rain,
      weathercode: weatherData.hourly.weatherCode,
      surfacePressure: weatherData.hourly.surfacePressure,
      visibility: weatherData.hourly.visibility,
      evapotranspiration: weatherData.hourly.evapotranspiration,
      windspeed10M: weatherData.hourly.windSpeed10M,
      winddirection10M: weatherData.hourly.windDirection10M,
      windgusts10M: weatherData.hourly.windGusts10M,
      cloudcover: weatherData.hourly.cloudCover,
      uvIndex: weatherData.hourly.uvIndex,
      dewpoint2M: weatherData.hourly.dewpoint2M,
      precipitationProbability: weatherData.hourly.precipitationProbability,
      shortwaveRadiation: weatherData.hourly.shortwaveRadiation,
      timeDaily: weatherData.daily.time,
      weathercodeDaily: weatherData.daily.weatherCode,
      temperature2MMax: weatherData.daily.temperature2MMax,
      temperature2MMin: weatherData.daily.temperature2MMin,
      apparentTemperatureMax: weatherData.daily.apparentTemperatureMax,
      apparentTemperatureMin: weatherData.daily.apparentTemperatureMin,
      sunrise: weatherData.daily.sunrise,
      sunset: weatherData.daily.sunset,
      precipitationSum: weatherData.daily.precipitationSum,
      precipitationProbabilityMax:
          weatherData.daily.precipitationProbabilityMax,
      windspeed10MMax: weatherData.daily.windSpeed10MMax,
      windgusts10MMax: weatherData.daily.windGusts10MMax,
      uvIndexMax: weatherData.daily.uvIndexMax,
      rainSum: weatherData.daily.rainSum,
      winddirection10MDominant: weatherData.daily.windDirection10MDominant,
      timezone: weatherData.timezone,
      timestamp: DateTime.now(),
    );
  }

  WeatherCard _mapWeatherDataToCard(
    WeatherDataApi weatherData,
    double lat,
    double lon,
    String city,
    String district,
    String timezone,
  ) => WeatherCard(
    time: weatherData.hourly.time,
    temperature2M: weatherData.hourly.temperature2M,
    relativehumidity2M: weatherData.hourly.relativeHumidity2M,
    apparentTemperature: weatherData.hourly.apparentTemperature,
    precipitation: weatherData.hourly.precipitation,
    rain: weatherData.hourly.rain,
    weathercode: weatherData.hourly.weatherCode,
    surfacePressure: weatherData.hourly.surfacePressure,
    visibility: weatherData.hourly.visibility,
    evapotranspiration: weatherData.hourly.evapotranspiration,
    windspeed10M: weatherData.hourly.windSpeed10M,
    winddirection10M: weatherData.hourly.windDirection10M,
    windgusts10M: weatherData.hourly.windGusts10M,
    cloudcover: weatherData.hourly.cloudCover,
    uvIndex: weatherData.hourly.uvIndex,
    dewpoint2M: weatherData.hourly.dewpoint2M,
    precipitationProbability: weatherData.hourly.precipitationProbability,
    shortwaveRadiation: weatherData.hourly.shortwaveRadiation,
    timeDaily: weatherData.daily.time,
    weathercodeDaily: weatherData.daily.weatherCode,
    temperature2MMax: weatherData.daily.temperature2MMax,
    temperature2MMin: weatherData.daily.temperature2MMin,
    apparentTemperatureMax: weatherData.daily.apparentTemperatureMax,
    apparentTemperatureMin: weatherData.daily.apparentTemperatureMin,
    sunrise: weatherData.daily.sunrise,
    sunset: weatherData.daily.sunset,
    precipitationSum: weatherData.daily.precipitationSum,
    precipitationProbabilityMax: weatherData.daily.precipitationProbabilityMax,
    windspeed10MMax: weatherData.daily.windSpeed10MMax,
    windgusts10MMax: weatherData.daily.windGusts10MMax,
    uvIndexMax: weatherData.daily.uvIndexMax,
    rainSum: weatherData.daily.rainSum,
    winddirection10MDominant: weatherData.daily.windDirection10MDominant,
    lat: lat,
    lon: lon,
    city: city,
    district: district,
    timezone: timezone,
    timestamp: DateTime.now(),
  );
}
