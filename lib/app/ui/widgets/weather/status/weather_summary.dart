import 'package:get/get.dart';

class WeatherSummary {
  /// Generates a friendly, contextual weather summary based on current conditions
  String getSummary({
    required int? weatherCode,
    required double? temperature,
    required double? feelsLike,
    required int? humidity,
    required double? windSpeed,
    required int? precipitationProbability,
    required int? uvIndex,
  }) {
    if (weatherCode == null || temperature == null) {
      return '';
    }

    final List<String> summaryParts = [];

    // Main weather condition description
    summaryParts.add(_getConditionDescription(weatherCode, temperature));

    // Temperature context
    final tempContext = _getTemperatureContext(temperature, feelsLike);
    if (tempContext.isNotEmpty) {
      summaryParts.add(tempContext);
    }

    // Weather-specific advice
    final advice = _getWeatherAdvice(
      weatherCode,
      windSpeed,
      precipitationProbability,
      uvIndex,
      humidity,
    );
    if (advice.isNotEmpty) {
      summaryParts.add(advice);
    }

    return summaryParts.join(' ');
  }

  String _getConditionDescription(int weatherCode, double temperature) {
    switch (weatherCode) {
      case 0:
        return temperature > 25
            ? 'weatherSummaryClearWarm'.tr
            : temperature < 10
            ? 'weatherSummaryClearCool'.tr
            : 'weatherSummaryClearMild'.tr;
      case 1:
      case 2:
        return 'weatherSummaryPartlyCloudy'.tr;
      case 3:
        return 'weatherSummaryOvercast'.tr;
      case 45:
      case 48:
        return 'weatherSummaryFoggy'.tr;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'weatherSummaryDrizzle'.tr;
      case 61:
      case 63:
      case 65:
        return 'weatherSummaryRainy'.tr;
      case 66:
      case 67:
        return 'weatherSummaryFreezingRain'.tr;
      case 80:
      case 81:
      case 82:
        return 'weatherSummaryShowers'.tr;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return 'weatherSummarySnowy'.tr;
      case 95:
      case 96:
      case 99:
        return 'weatherSummaryThunderstorm'.tr;
      default:
        return '';
    }
  }

  String _getTemperatureContext(double? temperature, double? feelsLike) {
    if (temperature == null || feelsLike == null) return '';

    final tempDiff = (temperature - feelsLike).abs();
    if (tempDiff >= 5) {
      if (feelsLike < temperature) {
        return 'weatherSummaryFeelsCooler'.tr;
      } else {
        return 'weatherSummaryFeelsWarmer'.tr;
      }
    }
    return '';
  }

  String _getWeatherAdvice(
    int weatherCode,
    double? windSpeed,
    int? precipChance,
    int? uvIndex,
    int? humidity,
  ) {
    // Precipitation advice
    if (precipChance != null && precipChance > 60) {
      if (weatherCode >= 61 && weatherCode <= 67 ||
          weatherCode >= 80 && weatherCode <= 82) {
        return 'weatherSummaryBringUmbrella'.tr;
      }
    }

    // Snow advice
    if (weatherCode >= 71 && weatherCode <= 77 ||
        weatherCode == 85 ||
        weatherCode == 86) {
      return 'weatherSummaryBundleUp'.tr;
    }

    // Thunderstorm advice
    if (weatherCode >= 95) {
      return 'weatherSummaryStayIndoors'.tr;
    }

    // Wind advice
    if (windSpeed != null && windSpeed > 30) {
      return 'weatherSummaryWindy'.tr;
    }

    // UV advice for clear weather
    if (uvIndex != null &&
        uvIndex > 6 &&
        (weatherCode == 0 || weatherCode <= 2)) {
      return 'weatherSummaryUseSunscreen'.tr;
    }

    // High humidity
    if (humidity != null && humidity > 80) {
      return 'weatherSummaryHumid'.tr;
    }

    // Pleasant weather
    if (weatherCode == 0 || weatherCode <= 2) {
      return 'weatherSummaryGreatDay'.tr;
    }

    return '';
  }
}
