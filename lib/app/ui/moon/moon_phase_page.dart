import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/utils/moon_phase.dart';
import 'package:intl/intl.dart';

class MoonPhasePage extends StatelessWidget {
  const MoonPhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final phase = MoonPhase.calculate(now);
    final phaseName = MoonPhase.getPhaseName(phase);
    final illumination = MoonPhase.getIllumination(phase);
    final nextFull = MoonPhase.nextFullMoon(now);
    final nextNew = MoonPhase.nextNewMoon(now);

    return Scaffold(
      appBar: AppBar(
        title: Text('moon_phase'.tr),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Current Moon Phase Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      MoonPhase.getPhaseEmoji(phase),
                      style: const TextStyle(fontSize: 120),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      phaseName.tr,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${illumination.toStringAsFixed(0)}% ${'illuminated'.tr}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Phase Progress Indicator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'phase_progress'.tr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: phase,
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🌑', style: const TextStyle(fontSize: 20)),
                        Text('🌓', style: const TextStyle(fontSize: 20)),
                        Text('🌕', style: const TextStyle(fontSize: 20)),
                        Text('🌗', style: const TextStyle(fontSize: 20)),
                        Text('🌑', style: const TextStyle(fontSize: 20)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upcoming Moon Events
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'upcoming_events'.tr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    _buildMoonEvent(
                      context,
                      icon: LucideIcons.moon,
                      title: 'next_full_moon'.tr,
                      date: nextFull,
                      emoji: '🌕',
                    ),
                    const Divider(height: 24),
                    _buildMoonEvent(
                      context,
                      icon: LucideIcons.moonStar,
                      title: 'next_new_moon'.tr,
                      date: nextNew,
                      emoji: '🌑',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Moon Phase Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'about_moon_phases'.tr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'moon_phase_info'.tr,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoonEvent(
    BuildContext context, {
    required IconData icon,
    required String title,
    required DateTime date,
    required String emoji,
  }) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();
    final daysUntil = date.difference(DateTime.now()).inDays;

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '${dateFormat.format(date)} • ${timeFormat.format(date)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${'in'.tr} $daysUntil ${'days'.tr}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
