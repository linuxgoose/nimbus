import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      required IconData icon,
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
            icon: icon,
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
        'icon': LucideIcons.thermometer,
        'desc': 'apparentTemperatureMin'.tr,
      },
      {
        'value': statusData.getDegree(widget.apparentTemperatureMax?.round()),
        'icon': LucideIcons.thermometer,
        'desc': 'apparentTemperatureMax'.tr,
      },
      {
        'value': widget.uvIndexMax?.round(),
        'icon': LucideIcons.sun,
        'desc': 'uvIndex'.tr,
        'message': message.getUvIndex(widget.uvIndexMax?.round()),
      },
      {
        'value': '${widget.windDirection10MDominant}°',
        'icon': LucideIcons.compass,
        'desc': 'direction'.tr,
        'message': message.getDirection(widget.windDirection10MDominant),
      },
      {
        'value': statusData.getSpeed(widget.windSpeed10MMax?.round()),
        'icon': LucideIcons.wind,
        'desc': 'wind'.tr,
      },
      {
        'value': statusData.getSpeed(widget.windGusts10MMax?.round()),
        'icon': LucideIcons.wind,
        'desc': 'windgusts'.tr,
      },
      {
        'value': '${widget.precipitationProbabilityMax}%',
        'icon': LucideIcons.umbrella,
        'desc': 'precipitationProbability'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.rainSum),
        'icon': LucideIcons.cloudRain,
        'desc': 'rain'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.precipitationSum),
        'icon': LucideIcons.cloudDrizzle,
        'desc': 'precipitation'.tr,
      },
      {
        'value': statusData.getDegree(widget.dewpoint2M?.round()),
        'icon': LucideIcons.droplets,
        'desc': 'dewpoint'.tr,
      },
      {
        'value': statusData.getDegree(widget.feels?.round()),
        'icon': LucideIcons.thermometer,
        'desc': 'feels'.tr,
      },
      {
        'value': statusData.getVisibility(widget.visibility),
        'icon': LucideIcons.eye,
        'desc': 'visibility'.tr,
      },
      {
        'value': '${widget.direction}°',
        'icon': LucideIcons.compass,
        'desc': 'direction'.tr,
        'message': message.getDirection(widget.direction),
      },
      {
        'value': statusData.getSpeed(widget.wind?.round()),
        'icon': LucideIcons.wind,
        'desc': 'wind'.tr,
      },
      {
        'value': statusData.getSpeed(widget.windgusts?.round()),
        'icon': LucideIcons.wind,
        'desc': 'windgusts'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.evaporation?.abs()),
        'icon': LucideIcons.droplet,
        'desc': 'evaporation'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.precipitation),
        'icon': LucideIcons.cloudDrizzle,
        'desc': 'precipitation'.tr,
      },
      {
        'value': statusData.getPrecipitation(widget.rain),
        'icon': LucideIcons.cloudRain,
        'desc': 'rain'.tr,
      },
      {
        'value': '${widget.precipitationProbability}%',
        'icon': LucideIcons.umbrella,
        'desc': 'precipitationProbability'.tr,
      },
      {
        'value': '${widget.humidity}%',
        'icon': Icons.water_rounded,
        'desc': 'humidity'.tr,
      },
      {
        'value': '${widget.cloudcover}%',
        'icon': Icons.cloud_rounded,
        'desc': 'cloudcover'.tr,
      },
      {
        'value': statusData.getPressure(widget.pressure?.round()),
        'icon': Icons.compress_rounded,
        'desc': 'pressure'.tr,
        'message': message.getPressure(widget.pressure?.round()),
      },
      {
        'value': widget.uvIndex?.round(),
        'icon': Icons.wb_sunny_rounded,
        'desc': 'uvIndex'.tr,
        'message': message.getUvIndex(widget.uvIndex?.round()),
      },
      {
        'value': '${widget.shortwaveRadiation?.round()} ${'W/m2'.tr}',
        'icon': Icons.light_mode_rounded,
        'desc': 'shortwaveRadiation'.tr,
      },
    ];

    for (var data in weatherData) {
      addDescriptionIfNotNull(
        value: data['value'],
        icon: data['icon'] as IconData,
        desc: '${data['desc']}',
        message: '${data['message']}',
      );
    }

    return descriptions;
  }
}
