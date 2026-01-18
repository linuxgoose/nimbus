import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nimbus/main.dart';

/// Service for fetching hiking and outdoor weather data from Open-Meteo
/// Includes UV index, visibility, wind conditions, and terrain-specific metrics
class HikingService {
  static final Dio _dio = Dio();

  /// Fetch hiking data for a location
  /// Returns hourly and daily hiking-relevant metrics
  static Future<Map<String, dynamic>?> getHikingData({
    required double lat,
    required double lon,
  }) async {
    try {
      String baseUrl = 'https://api.open-meteo.com';

      // Use Nimbus Meteo if selected
      if (settings.weatherDataSource == 'nimbusmeteo') {
        baseUrl = 'https://nimbusmeteo.linuxgoose.com';
      } else if (settings.useCustomOpenMeteoEndpoint &&
          settings.customOpenMeteoUrl != null &&
          settings.customOpenMeteoUrl!.isNotEmpty) {
        baseUrl = settings.customOpenMeteoUrl!;
      }

      final url = '$baseUrl/v1/forecast';

      debugPrint('🥾 Calling Hiking API: $url');

      final response = await _dio.get(
        url,
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'hourly': [
            'temperature_2m',
            'apparent_temperature',
            'precipitation',
            'rain',
            'snowfall',
            'snow_depth',
            'weather_code',
            'visibility',
            'wind_speed_10m',
            'wind_gusts_10m',
            'wind_direction_10m',
            'uv_index',
            'is_day',
            'sunshine_duration',
            'cape',
            'freezing_level_height',
          ].join(','),
          'daily': [
            'temperature_2m_max',
            'temperature_2m_min',
            'apparent_temperature_max',
            'apparent_temperature_min',
            'sunrise',
            'sunset',
            'daylight_duration',
            'sunshine_duration',
            'uv_index_max',
            'precipitation_sum',
            'rain_sum',
            'snowfall_sum',
            'precipitation_hours',
            'wind_speed_10m_max',
            'wind_gusts_10m_max',
          ].join(','),
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Hiking API Success');
        return response.data as Map<String, dynamic>;
      } else {
        debugPrint('❌ Hiking API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Hiking API Exception: $e');
      return null;
    }
  }

  /// Get UV index category and safety recommendation
  static String getUVCategory(double uvIndex) {
    if (uvIndex < 3) return 'Low - Minimal protection needed';
    if (uvIndex < 6) return 'Moderate - Seek shade during midday';
    if (uvIndex < 8) return 'High - Protection essential';
    if (uvIndex < 11) return 'Very High - Extra protection required';
    return 'Extreme - Avoid sun exposure';
  }

  /// Get visibility category
  static String getVisibilityCategory(double visibilityKm) {
    if (visibilityKm >= 20) return 'Excellent';
    if (visibilityKm >= 10) return 'Good';
    if (visibilityKm >= 4) return 'Moderate';
    if (visibilityKm >= 1) return 'Poor';
    return 'Very Poor';
  }

  /// Get wind speed category for hiking
  static String getWindCategory(double windSpeedKmh) {
    if (windSpeedKmh < 12) return 'Calm - Ideal';
    if (windSpeedKmh < 20) return 'Light Breeze - Pleasant';
    if (windSpeedKmh < 30) return 'Moderate - Noticeable';
    if (windSpeedKmh < 40) return 'Fresh - Difficult';
    if (windSpeedKmh < 50) return 'Strong - Hazardous';
    return 'Very Strong - Dangerous';
  }

  /// Get hiking conditions rating based on multiple factors
  static String getHikingConditions({
    required double temp,
    required double? precipitation,
    required double? windSpeed,
    required double? visibility,
  }) {
    int score = 0;

    // Temperature scoring (ideal: 10-25°C)
    if (temp >= 10 && temp <= 25) {
      score += 3;
    } else if (temp >= 5 && temp <= 30) {
      score += 2;
    } else if (temp >= 0 && temp <= 35) {
      score += 1;
    }

    // Precipitation scoring
    if (precipitation == null || precipitation < 0.1) {
      score += 2;
    } else if (precipitation < 2.0) {
      score += 1;
    }

    // Wind scoring
    if (windSpeed == null || windSpeed < 20) {
      score += 2;
    } else if (windSpeed < 30) {
      score += 1;
    }

    // Visibility scoring
    if (visibility == null || visibility >= 10) {
      score += 2;
    } else if (visibility >= 4) {
      score += 1;
    }

    // Return rating based on score
    if (score >= 8) return 'Excellent - Perfect for hiking';
    if (score >= 6) return 'Good - Favorable conditions';
    if (score >= 4) return 'Fair - Acceptable with caution';
    if (score >= 2) return 'Poor - Challenging conditions';
    return 'Hazardous - Not recommended';
  }

  /// Get snow depth category
  static String getSnowDepthCategory(double snowDepthCm) {
    if (snowDepthCm < 1) return 'None';
    if (snowDepthCm < 10) return 'Light - Passable';
    if (snowDepthCm < 30) return 'Moderate - Difficult';
    if (snowDepthCm < 60) return 'Heavy - Snowshoes needed';
    return 'Very Heavy - Extreme caution';
  }

  /// Get daylight duration description
  static String getDaylightDescription(double daylightHours) {
    if (daylightHours < 8) return 'Short day - Plan accordingly';
    if (daylightHours < 12) return 'Moderate daylight';
    if (daylightHours < 14) return 'Good daylight hours';
    return 'Long day - Excellent';
  }

  /// Get CAPE (Convective Available Potential Energy) thunderstorm risk
  static String getThunderstormRisk(double cape) {
    if (cape < 300) return 'None - Stable';
    if (cape < 1000) return 'Low - Unlikely';
    if (cape < 2500) return 'Moderate - Possible';
    if (cape < 4000) return 'High - Likely';
    return 'Extreme - Severe storms possible';
  }
}
