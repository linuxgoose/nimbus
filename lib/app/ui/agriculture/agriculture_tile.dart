import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/ui/agriculture/view/agriculture_page.dart';
import 'package:nimbus/app/controller/controller.dart';

class AgricultureTile extends StatelessWidget {
  const AgricultureTile({super.key});

  @override
  Widget build(BuildContext context) {
    final weatherController = Get.find<WeatherController>();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AgriculturePage(
              lat: weatherController.location.lat ?? 51.5074,
              lon: weatherController.location.lon ?? -0.1278,
              locationName: weatherController.location.city ?? 'Unknown',
            ),
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
                color: Colors.green.withAlpha(51),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(LucideIcons.sprout, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agriculture',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Soil conditions & farming data',
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
