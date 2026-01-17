import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/services/flood_service.dart';
import 'package:nimbus/app/ui/flood/view/flood_page.dart';
import 'package:nimbus/app/controller/controller.dart';
import 'package:nimbus/main.dart';

class FloodTile extends StatefulWidget {
  const FloodTile({super.key});

  @override
  State<FloodTile> createState() => _FloodTileState();
}

class _FloodTileState extends State<FloodTile> {
  final weatherController = Get.find<WeatherController>();
  int warningCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    try {
      final lat = weatherController.location.lat ?? 51.5074;
      final lon = weatherController.location.lon ?? -0.1278;

      final warnings = await FloodService.getAllUKFloodWarnings(
        lat: lat,
        lon: lon,
        radiusKm: settings.floodRadiusKm,
      );

      if (mounted) {
        setState(() {
          warningCount = warnings.length;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Get.to(() => const FloodPage(), transition: Transition.downToUp),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.waves,
                  size: 32,
                  color: context.theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UK Flood Monitoring',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoading
                          ? 'Loading flood data...'
                          : warningCount > 0
                          ? '$warningCount active warning${warningCount != 1 ? 's' : ''} nearby'
                          : 'View flood warnings and river levels',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: warningCount > 0
                            ? Colors.orange
                            : context.theme.colorScheme.onSurfaceVariant,
                        fontWeight: warningCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.arrowRight,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
