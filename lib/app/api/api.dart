import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nimbus/app/api/city_api.dart';
import 'package:nimbus/app/api/weather_api.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/app/services/hybrid_weather_service.dart';
import 'package:nimbus/main.dart';

class WeatherAPI {
  // Base URL updated to exclude the '?' to handle queryParameters cleanly via Dio
  final Dio dio = Dio()
    ..options.baseUrl = 'https://api.open-meteo.com/v1/forecast';
  final Dio dioLocation = Dio();

  // Added alerts=true and models=gem_global for boundary/polygon data
  static const String _weatherParams =
      'hourly=temperature_2m,relativehumidity_2m,apparent_temperature,precipitation,rain,weathercode,surface_pressure,visibility,evapotranspiration,windspeed_10m,winddirection_10m,windgusts_10m,cloudcover,uv_index,dewpoint_2m,precipitation_probability,shortwave_radiation'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,windspeed_10m_max,windgusts_10m_max,uv_index_max,rain_sum,winddirection_10m_dominant'
      '&forecast_days=12&timezone=auto'
      '&alerts=true' // Required for weather warnings
      '&models=gem_global'; // Best model for global alert polygons

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
    // Check if we should use hybrid/MET Norway service
    if (settings.weatherDataSource == 'metno' || settings.weatherDataSource == 'hybrid') {
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
          debugPrint('⚠️ Hybrid service returned null, falling back to Open-Meteo');
        }
      } catch (e) {
        debugPrint('❌ Hybrid service error: $e, falling back to Open-Meteo');
      }
    }
    
    // Default: Use Open-Meteo
    final String urlWeather = _buildWeatherUrl(lat, lon);
    try {
      Response response = await dio.get(urlWeather);
      WeatherDataApi weatherData = WeatherDataApi.fromJson(response.data);
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
    if (settings.weatherDataSource == 'metno' || settings.weatherDataSource == 'hybrid') {
      try {
        debugPrint('🚨 Fetching alerts via hybrid service');
        final hybridAlerts = await HybridWeatherService.getWeatherAlerts(
          lat: lat,
          lon: lon,
        );
        
        if (hybridAlerts.isNotEmpty) {
          debugPrint('✅ Found ${hybridAlerts.length} alerts from hybrid service');
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
        final severity = (alert['severity']?.toString() ?? 'moderate').toLowerCase();
        
        // Create unique key combining location and event
        final eventKey = '${lat.toStringAsFixed(4)}_${lon.toStringAsFixed(4)}_${timestamp.millisecondsSinceEpoch}_$event';
        
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
    // Check if we should use hybrid/MET Norway service
    if (settings.weatherDataSource == 'metno' || settings.weatherDataSource == 'hybrid') {
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
          debugPrint('⚠️ Hybrid service returned null, falling back to Open-Meteo');
        }
      } catch (e) {
        debugPrint('❌ Hybrid service error: $e, falling back to Open-Meteo');
      }
    }
    
    // Default: Use Open-Meteo
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
    final String url =
        'https://geocoding-api.open-meteo.com/v1/search?name=$query&count=5&language=${locale?.languageCode}&format=json';
    try {
      Response response = await dioLocation.get(url);
      if (response.statusCode == 200) {
        CityApi cityData = CityApi.fromJson(response.data);
        return cityData.results.map(
          (e) => Result(
            admin1: e.admin1,
            name: e.name,
            latitude: e.latitude,
            longitude: e.longitude,
          ),
        );
      } else {
        throw Exception('Failed to load suggestions');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      rethrow;
    }
  }

  MainWeatherCache _mapWeatherDataToCache(WeatherDataApi weatherData) =>
      MainWeatherCache(
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
