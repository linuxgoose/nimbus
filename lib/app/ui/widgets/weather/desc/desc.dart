import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';

class DescWeather extends StatefulWidget {
  const DescWeather({
    super.key,
    required this.imageName,
    required this.value,
    required this.desc,
    this.message = '',
  });

  final String imageName;
  final String value;
  final String desc;
  final String? message;

  @override
  State<DescWeather> createState() => _DescWeatherState();
}

class _DescWeatherState extends State<DescWeather> {
  bool hide = true;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _toggleDescriptionVisibility,
    child: Tooltip(
      message: widget.message,
      child: Container(
        height: 100,
        width: 100,
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.theme.colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: _buildContent(context.textTheme),
      ),
    ),
  );

  void _toggleDescriptionVisibility() => setState(() => hide = !hide);

  Widget _buildContent(TextTheme textTheme) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(widget.imageName, scale: 20),
        const Gap(6),
        Text(
          widget.value,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(2),
        Expanded(
          child: Text(
            widget.desc,
            style: textTheme.bodySmall?.copyWith(
              color: textTheme.bodySmall?.color?.withOpacity(0.7),
            ),
            overflow: hide ? TextOverflow.ellipsis : TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
