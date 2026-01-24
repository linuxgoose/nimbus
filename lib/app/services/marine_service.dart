import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nimbus/main.dart';

/// Service for fetching marine weather data from Open-Meteo
/// Includes wave height, swell, ocean currents, and tides
class MarineService {
  static final Dio _dio = Dio();

  /// Fetch marine data for a location
  /// Returns hourly and daily marine metrics
  static Future<Map<String, dynamic>?> getMarineData({
    required double lat,
    required double lon,
  }) async {
    try {
      String baseUrl = 'https://marine-api.open-meteo.com';

      // Use Nimbus Meteo if selected
      if (settings.weatherDataSource == 'nimbusmeteo') {
        baseUrl = 'https://nimbusmeteo.linuxgoose.com';
      } else if (settings.useCustomOpenMeteoEndpoint &&
          settings.customMarineUrl != null &&
          settings.customMarineUrl!.isNotEmpty) {
        baseUrl = settings.customMarineUrl!;
      }

      final url = '$baseUrl/v1/marine';

      debugPrint('🌊 Calling Marine API: $url');

      final response = await _dio.get(
        url,
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'hourly': [
            'wave_height',
            'wave_direction',
            'wave_period',
            'wind_wave_height',
            'wind_wave_direction',
            'wind_wave_period',
            'swell_wave_height',
            'swell_wave_direction',
            'swell_wave_period',
            'ocean_current_velocity',
            'ocean_current_direction',
          ].join(','),
          'daily': [
            'wave_height_max',
            'wave_direction_dominant',
            'wave_period_max',
            'wind_wave_height_max',
            'swell_wave_height_max',
          ].join(','),
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Marine API Success');
        return response.data as Map<String, dynamic>;
      } else {
        debugPrint('❌ Marine API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Marine API Exception: $e');
      return null;
    }
  }

  /// Get wave height category based on height in meters
  static String getWaveCategory(double waveHeight) {
    if (waveHeight < 0.5) return 'Calm';
    if (waveHeight < 1.25) return 'Smooth';
    if (waveHeight < 2.5) return 'Slight';
    if (waveHeight < 4.0) return 'Moderate';
    if (waveHeight < 6.0) return 'Rough';
    if (waveHeight < 9.0) return 'Very Rough';
    if (waveHeight < 14.0) return 'High';
    return 'Very High';
  }

  /// Get swell category
  static String getSwellCategory(double swellHeight) {
    if (swellHeight < 1.0) return 'Low Swell';
    if (swellHeight < 2.0) return 'Moderate Swell';
    if (swellHeight < 4.0) return 'Heavy Swell';
    return 'Very Heavy Swell';
  }

  /// Get ocean current speed category (m/s)
  static String getCurrentCategory(double currentSpeed) {
    if (currentSpeed < 0.25) return 'Negligible';
    if (currentSpeed < 0.5) return 'Weak';
    if (currentSpeed < 1.0) return 'Moderate';
    if (currentSpeed < 2.0) return 'Strong';
    return 'Very Strong';
  }

  /// Get wave period description
  static String getWavePeriodDescription(double period) {
    if (period < 5) return 'Short period (choppy)';
    if (period < 8) return 'Moderate period';
    if (period < 12) return 'Long period (smooth)';
    return 'Very long period';
  }

  /// Get safety recommendation based on conditions
  static String getSafetyRecommendation(
    double waveHeight,
    double? windWaveHeight,
  ) {
    if (waveHeight < 1.0 && (windWaveHeight == null || windWaveHeight < 0.5)) {
      return 'Excellent conditions for all activities';
    } else if (waveHeight < 2.0) {
      return 'Good for most water activities';
    } else if (waveHeight < 3.0) {
      return 'Caution advised for small boats';
    } else if (waveHeight < 5.0) {
      return 'Rough conditions - experienced only';
    }
    return 'Hazardous conditions - avoid';
  }
}
