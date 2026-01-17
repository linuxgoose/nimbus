import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/desc.dart';
import 'package:nimbus/app/ui/widgets/weather/desc/message.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_data.dart';

class DescContainer extends StatefulWidget {
  const DescContainer({
    super.key,
    this.humidity,
    this.wind,
    this.visibility,
    this.feels,
    this.evaporation,
    this.precipitation,
    this.direction,
    this.pressure,
    this.rain,
    this.cloudcover,
    this.windgusts,
    this.uvIndex,
    this.dewpoint2M,
    this.precipitationProbability,
    this.shortwaveRadiation,
    this.apparentTemperatureMin,
    this.apparentTemperatureMax,
    this.uvIndexMax,
    this.windDirection10MDominant,
    this.windSpeed10MMax,
    this.windGusts10MMax,
    this.precipitationProbabilityMax,
    this.rainSum,
    this.precipitationSum,
    required this.initiallyExpanded,
    required this.title,
  });

  final int? humidity;
  final double? wind;
  final double? visibility;
  final double? feels;
  final double? evaporation;
  final double? precipitation;
  final int? direction;
  final double? pressure;
  final double? rain;
  final int? cloudcover;
  final double? windgusts;
  final double? uvIndex;
  final double? dewpoint2M;
  final int? precipitationProbability;
  final double? shortwaveRadiation;
  final double? apparentTemperatureMin;
  final double? apparentTemperatureMax;
  final double? uvIndexMax;
  final int? windDirection10MDominant;
  final double? windSpeed10MMax;
  final double? windGusts10MMax;
  final int? precipitationProbabilityMax;
  final double? rainSum;
  final double? precipitationSum;
  final bool initiallyExpanded;
  final String title;

  @override
  State<DescContainer> createState() => _DescContainerState();
}

class _DescContainerState extends State<DescContainer> {
  final statusData = StatusData();
  final message = Message();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: ExpansionTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: context.theme.colorScheme.surfaceContainerHighest
          .withOpacity(0.3),
      collapsedBackgroundColor: Colors.transparent,
      title: Row(
        children: [
          Icon(
            Icons.thermostat_rounded,
            size: 20,
            color: context.theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            widget.title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      initiallyExpanded: widget.initiallyExpanded,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 8,
            children: _buildWeatherDescriptions(context),
          ),
        ),
      ],
    ),
  );

  List<Widget> _buildWeatherDescriptions(BuildContext context) {
    final List<Widget> descriptions = [];

    void addDescriptionIfNotNull({
      required dynamic value,
      required String imageName,
      required String desc,
      String? message,
    }) {
      if (value != null &&
          value != '' &&
          value != 'null°C' &&
          value != 'null°F' &&
          value != 'null°' &&
          value != 'null%' &&
          value != 'null ${'W/m2'.tr}') {
        descriptions.add(
          DescWeather(
            imageName: imageName,
            value: value.toString(),
            desc: desc,
            message: message ?? '',
          ),
        );
      } else {
        descriptions.add(Container());
      }
    }

    final weatherData = [
      {
        'value': statusData.getDegree(widget.apparentTemperatureMin?.round()),
        'imageName':
            'assets/images/wi-snowflake${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'apparentTemperatureMin'.tr,
      },
      {
        'value': statusData.getDegree(widget.apparentTemperatureMax?.round()),
        'imageName': 'assets/images/wi-sun${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'apparentTemperatureMax'.tr,
      },
      {
        'value': widget.uvIndexMax?.round(),
        'imageName': 'assets/images/wi-sun${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'uvIndex'.tr,
        'message': message.getUvIndex(widget.uvIndexMax?.round()),
      },
      {
        'value': '${widget.windDirection10MDominant}°',
        'imageName':
            'assets/images/wi-wind-direction${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'direction'.tr,
        'message': message.getDirection(widget.windDirection10MDominant),
      },
      {
        'value': statusData.getSpeed(widget.windSpeed10MMax?.round()),
        'imageName':
            'assets/images/wi-wind-speed${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'wind'.tr,
      },
      {
        'value': statusData.getSpeed(widget.windGusts10MMax?.round()),
        'imageName':
            'assets/images/wi-wind-gust${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'windgusts'.tr,
      },
      {
        'value': '${widget.precipitationProbabilityMax}%',
        'imageName':
            'assets/images/wi-umbrella${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'precipitationProbability'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.rainSum),
        'imageName': 'assets/images/wi-rain${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'rain'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.precipitationSum),
        'imageName':
            'assets/images/wi-precipitation${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'precipitation'.tr,
      },
      {
        'value': statusData.getDegree(widget.dewpoint2M?.round()),
        'imageName':
            'assets/images/wi-dewpoint${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'dewpoint'.tr,
      },
      {
        'value': statusData.getDegree(widget.feels?.round()),
        'imageName':
            'assets/images/wi-thermometer${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'feels'.tr,
      },
      {
        'value': statusData.getVisibility(widget.visibility),
        'imageName': 'assets/images/wi-fog${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'visibility'.tr,
      },
      {
        'value': '${widget.direction}°',
        'imageName':
            'assets/images/wi-wind-direction${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'direction'.tr,
        'message': message.getDirection(widget.direction),
      },
      {
        'value': statusData.getSpeed(widget.wind?.round()),
        'imageName':
            'assets/images/wi-wind-speed${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'wind'.tr,
      },
      {
        'value': statusData.getSpeed(widget.windgusts?.round()),
        'imageName':
            'assets/images/wi-wind-gust${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'windgusts'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.evaporation?.abs()),
        'imageName':
            'assets/images/wi-raindrops${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'evaporation'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.precipitation),
        'imageName':
            'assets/images/wi-precipitation${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'precipitation'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.rain),
        'imageName': 'assets/images/wi-rain${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'rain'.tr,
      },
      {
        'value': '${widget.precipitationProbability}%',
        'imageName':
            'assets/images/wi-umbrella${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'precipitationProbability'.tr,
      },
      {
        'value': '${widget.humidity}%',
        'imageName':
            'assets/images/wi-humidity${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'humidity'.tr,
      },
      {
        'value': '${widget.cloudcover}%',
        'imageName': 'assets/images/wi-cloudy${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'cloudcover'.tr,
      },
      {
        'value': statusData.getPressure(widget.pressure?.round()),
        'imageName':
            'assets/images/wi-barometer${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'pressure'.tr,
        'message': message.getPressure(widget.pressure?.round()),
      },
      {
        'value': widget.uvIndex?.round(),
        'imageName': 'assets/images/wi-sun${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'uvIndex'.tr,
        'message': message.getUvIndex(widget.uvIndex?.round()),
      },
      {
        'value': '${widget.shortwaveRadiation?.round()} ${'W/m2'.tr}',
        'imageName': 'assets/images/wi-hot${Get.isDarkMode ? "-w" : ""}.png',
        'desc': 'shortwaveRadiation'.tr,
      },
    ];

    for (var data in weatherData) {
      addDescriptionIfNotNull(
        value: data['value'],
        imageName: '${data['imageName']}',
        desc: '${data['desc']}',
        message: '${data['message']}',
      );
    }

    return descriptions;
  }
}
