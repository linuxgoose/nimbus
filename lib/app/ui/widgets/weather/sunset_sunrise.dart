import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rain/app/ui/widgets/weather/status/status_data.dart';

class SunsetSunrise extends StatefulWidget {
  const SunsetSunrise({
    super.key,
    required this.timeSunrise,
    required this.timeSunset,
  });

  final String timeSunrise;
  final String timeSunset;

  @override
  State<SunsetSunrise> createState() => _SunsetSunriseState();
}

class _SunsetSunriseState extends State<SunsetSunrise> {
  final statusData = StatusData();

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final titleSmall = textTheme.titleSmall;
    final titleLarge = textTheme.titleLarge;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Row(
          children: [
            _buildSunTimeColumn(
              context,
              'sunrise'.tr,
              statusData.getTimeFormat(widget.timeSunrise),
              'assets/images/sunrise.png',
              titleSmall,
              titleLarge,
            ),
            _buildSunTimeColumn(
              context,
              'sunset'.tr,
              statusData.getTimeFormat(widget.timeSunset),
              'assets/images/sunset.png',
              titleSmall,
              titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSunTimeColumn(
    BuildContext context,
    String label,
    String time,
    String imagePath,
    TextStyle? labelStyle,
    TextStyle? timeStyle,
  ) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 5,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label, style: labelStyle, overflow: TextOverflow.ellipsis),
              Text(time, style: timeStyle),
            ],
          ),
        ),
        Flexible(child: Image.asset(imagePath, scale: 10)),
      ],
    ),
  );
}
