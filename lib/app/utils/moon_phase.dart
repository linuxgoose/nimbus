/// Calculates moon phases and provides moon information
class MoonPhase {
  /// Calculate the moon phase for a given date
  /// Returns a value between 0 and 1:
  /// 0.0 = New Moon
  /// 0.25 = First Quarter
  /// 0.5 = Full Moon
  /// 0.75 = Last Quarter
  static double calculate(DateTime date) {
    // Convert to Julian Date
    final int year = date.year;
    final int month = date.month;
    final double day =
        date.day +
        (date.hour / 24.0) +
        (date.minute / 1440.0) +
        (date.second / 86400.0);

    int a = (14 - month) ~/ 12;
    int y = year + 4800 - a;
    int m = month + 12 * a - 3;

    double jd =
        day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;

    // Calculate days since known new moon (Jan 6, 2000)
    final double daysSinceNew = jd - 2451549.5;
    final double newMoons = daysSinceNew / 29.53058867; // Synodic month length
    final double phase = newMoons - newMoons.floor();

    return phase;
  }

  /// Get the moon phase name
  static String getPhaseName(double phase) {
    if (phase < 0.0335 || phase >= 0.9665) {
      return 'new_moon';
    } else if (phase < 0.2165) {
      return 'waxing_crescent';
    } else if (phase < 0.2835) {
      return 'first_quarter';
    } else if (phase < 0.4665) {
      return 'waxing_gibbous';
    } else if (phase < 0.5335) {
      return 'full_moon';
    } else if (phase < 0.7165) {
      return 'waning_gibbous';
    } else if (phase < 0.7835) {
      return 'last_quarter';
    } else {
      return 'waning_crescent';
    }
  }

  /// Get illumination percentage (0-100)
  static double getIllumination(double phase) {
    // Calculate illumination based on phase
    if (phase <= 0.5) {
      return phase * 200; // 0 to 100
    } else {
      return (1 - phase) * 200; // 100 to 0
    }
  }

  /// Get the emoji icon for the moon phase
  static String getPhaseEmoji(double phase) {
    if (phase < 0.0335 || phase >= 0.9665) {
      return '🌑'; // New Moon
    } else if (phase < 0.2165) {
      return '🌒'; // Waxing Crescent
    } else if (phase < 0.2835) {
      return '🌓'; // First Quarter
    } else if (phase < 0.4665) {
      return '🌔'; // Waxing Gibbous
    } else if (phase < 0.5335) {
      return '🌕'; // Full Moon
    } else if (phase < 0.7165) {
      return '🌖'; // Waning Gibbous
    } else if (phase < 0.7835) {
      return '🌗'; // Last Quarter
    } else {
      return '🌘'; // Waning Crescent
    }
  }

  /// Calculate the date of the next full moon
  static DateTime nextFullMoon(DateTime from) {
    final currentPhase = calculate(from);
    double daysToFullMoon;

    if (currentPhase < 0.5) {
      // Before full moon
      daysToFullMoon = (0.5 - currentPhase) * 29.53058867;
    } else {
      // After full moon, get next one
      daysToFullMoon = (1.5 - currentPhase) * 29.53058867;
    }

    return from.add(
      Duration(
        days: daysToFullMoon.floor(),
        hours: ((daysToFullMoon - daysToFullMoon.floor()) * 24).round(),
      ),
    );
  }

  /// Calculate the date of the next new moon
  static DateTime nextNewMoon(DateTime from) {
    final currentPhase = calculate(from);
    double daysToNewMoon;

    if (currentPhase < 1.0) {
      // Before next new moon
      daysToNewMoon = (1.0 - currentPhase) * 29.53058867;
    } else {
      // At new moon
      daysToNewMoon = 0;
    }

    return from.add(
      Duration(
        days: daysToNewMoon.floor(),
        hours: ((daysToNewMoon - daysToNewMoon.floor()) * 24).round(),
      ),
    );
  }

  /// Get a detailed description of the moon phase
  static String getPhaseDescription(double phase) {
    final phaseName = getPhaseName(phase);
    final illumination = getIllumination(phase).toStringAsFixed(0);

    return '$phaseName ($illumination% illuminated)';
  }
}
