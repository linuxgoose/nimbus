import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/utils/moon_phase.dart';
import 'package:nimbus/app/ui/moon/moon_phase_page.dart';

class MoonPhaseTile extends StatelessWidget {
  const MoonPhaseTile({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final phase = MoonPhase.calculate(now);
    final phaseName = MoonPhase.getPhaseName(phase);
    final illumination = MoonPhase.getIllumination(phase);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () => Get.to(() => const MoonPhasePage()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.moon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'moon_phase'.tr,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    MoonPhase.getPhaseEmoji(phase),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          phaseName.tr,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${illumination.toStringAsFixed(0)}% ${'illuminated'.tr}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
