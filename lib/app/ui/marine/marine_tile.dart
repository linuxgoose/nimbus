import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/app/ui/marine/view/marine_page.dart';

class MarineTile extends StatelessWidget {
  const MarineTile({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherController = Get.find<WeatherController>();

    return GestureDetector(
      onTap: () {
        Get.to(
          () => MarinePage(
            lat: weatherController.location.lat ?? 0.0,
            lon: weatherController.location.lon ?? 0.0,
            locationName: weatherController.location.city ?? 'Unknown',
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.waves,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marine',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wave height, swell & ocean conditions',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
