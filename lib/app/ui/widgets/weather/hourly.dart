import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_data.dart';
import 'package:nimbus/app/ui/widgets/weather/status/status_weather.dart';
import 'package:nimbus/main.dart';

class Hourly extends StatefulWidget {
  const Hourly({
    super.key,
    required this.time,
    required this.weather,
    required this.degree,
    required this.timeDay,
    required this.timeNight,
  });

  final String time;
  final String timeDay;
  final String timeNight;
  final int? weather;
  final double? degree;

  @override
  State<Hourly> createState() => _HourlyState();
}

class _HourlyState extends State<Hourly> {
  final statusWeather = StatusWeather();
  final statusData = StatusData();

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final time = widget.time;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeText(textTheme, time),
        const SizedBox(height: 6),
        _buildWeatherImage(),
        const SizedBox(height: 6),
        _buildTemperatureText(textTheme),
      ],
    );
  }

  Widget _buildTimeText(TextTheme textTheme, String time) => Column(
    children: [
      Text(
        statusData.getTimeFormat(time),
        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 2),
      Text(
        DateFormat('E', locale.languageCode).format(DateTime.tryParse(time)!),
        style: textTheme.labelSmall?.copyWith(
          color: textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
      ),
    ],
  );

  Widget _buildWeatherImage() => Icon(
    statusWeather.getIconToday(
      widget.weather,
      widget.time,
      widget.timeDay,
      widget.timeNight,
    ),
    size: 36,
    color: context.theme.colorScheme.primary,
  );

  Widget _buildTemperatureText(TextTheme textTheme) => Text(
    statusData.getDegree((widget.degree ?? 0).round()),
    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );
}
