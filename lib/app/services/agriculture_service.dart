import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service for fetching agriculture-specific weather data from Open-Meteo
/// Includes soil conditions, evapotranspiration, and farming metrics
class AgricultureService {
  static final Dio _dio = Dio();

  /// Fetch agriculture data for a location
  /// Returns hourly and daily agriculture metrics
  static Future<Map<String, dynamic>?> getAgricultureData({
    required double lat,
    required double lon,
  }) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast';

      debugPrint('🌾 Calling Agriculture API: $url');

      final response = await _dio.get(
        url,
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'hourly': [
            'soil_temperature_0cm',
            'soil_temperature_6cm',
            'soil_temperature_18cm',
            'soil_temperature_54cm',
            'soil_moisture_0_to_1cm',
            'soil_moisture_1_to_3cm',
            'soil_moisture_3_to_9cm',
            'soil_moisture_9_to_27cm',
            'soil_moisture_27_to_81cm',
            'evapotranspiration',
            'et0_fao_evapotranspiration',
            'vapour_pressure_deficit',
            'precipitation',
            'rain',
            'temperature_2m',
            'relative_humidity_2m',
            'shortwave_radiation',
            'wind_speed_10m',
            'freezing_level_height',
          ].join(','),
          'daily': [
            'et0_fao_evapotranspiration',
            'precipitation_sum',
            'rain_sum',
            'temperature_2m_max',
            'temperature_2m_min',
            'shortwave_radiation_sum',
            'precipitation_hours',
          ].join(','),
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Agriculture API Success');
        return response.data as Map<String, dynamic>;
      } else {
        debugPrint('❌ Agriculture API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Agriculture API Exception: $e');
      return null;
    }
  }

  /// Calculate growing degree days (GDD) from temperature data
  /// Base temperature is typically 10°C for most crops
  static double calculateGDD(
    double tempMax,
    double tempMin, {
    double baseTemp = 10.0,
  }) {
    final avgTemp = (tempMax + tempMin) / 2;
    final gdd = avgTemp - baseTemp;
    return gdd > 0 ? gdd : 0;
  }

  /// Get soil moisture category based on volumetric water content
  static String getSoilMoistureCategory(double moisture) {
    if (moisture < 0.1) return 'Very Dry';
    if (moisture < 0.2) return 'Dry';
    if (moisture < 0.3) return 'Adequate';
    if (moisture < 0.4) return 'Moist';
    return 'Saturated';
  }

  /// Get VPD (Vapour Pressure Deficit) category
  static String getVPDCategory(double vpd) {
    if (vpd < 0.4) return 'Low (reduced transpiration)';
    if (vpd < 0.8) return 'Optimal';
    if (vpd < 1.2) return 'Moderate';
    if (vpd < 1.6) return 'High';
    return 'Very High (plant stress)';
  }

  /// Get ET₀ recommendation for irrigation
  static String getET0Recommendation(double et0Daily) {
    if (et0Daily < 2) return 'Low water demand';
    if (et0Daily < 4) return 'Moderate water demand';
    if (et0Daily < 6) return 'High water demand';
    return 'Very high water demand';
  }
}
