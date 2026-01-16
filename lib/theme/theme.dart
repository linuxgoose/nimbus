import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dynamic_color/dynamic_color.dart';

final ThemeData baseLight = ThemeData.light(useMaterial3: true);
final ThemeData baseDark = ThemeData.dark(useMaterial3: true);

// Nimbus Minimalist Palette
const Color nimbusAccent = Color(0xFF8CA7B3); // Muted blue-grey splash
const Color lightColor = Color(0xFFF5F5F7); // Soft off-white
const Color darkColor = Color(0xFF121212); // Deep matte charcoal
const Color oledColor = Colors.black;

// --- Brand Color Schemes ---
ColorScheme colorSchemeLight = ColorScheme.fromSeed(
  seedColor: nimbusAccent,
  brightness: Brightness.light,
  surface: lightColor,
);

ColorScheme colorSchemeDark = ColorScheme.fromSeed(
  seedColor: nimbusAccent,
  brightness: Brightness.dark,
  surface: darkColor,
);

ThemeData lightTheme(
  Color? color,
  ColorScheme? colorScheme,
  bool edgeToEdgeAvailable,
) => _buildTheme(
  baseTheme: baseLight,
  brightness: Brightness.light,
  color: color ?? lightColor,
  colorScheme: colorScheme ?? colorSchemeLight,
  edgeToEdgeAvailable: edgeToEdgeAvailable,
);

ThemeData darkTheme(
  Color? color,
  ColorScheme? colorScheme,
  bool edgeToEdgeAvailable,
) => _buildTheme(
  baseTheme: baseDark,
  brightness: Brightness.dark,
  color: color ?? darkColor,
  colorScheme: colorScheme ?? colorSchemeDark,
  edgeToEdgeAvailable: edgeToEdgeAvailable,
);

ThemeData _buildTheme({
  required ThemeData baseTheme,
  required Brightness brightness,
  required Color? color,
  required ColorScheme? colorScheme,
  required bool edgeToEdgeAvailable,
}) {
  final harmonizedColorScheme = colorScheme
      ?.copyWith(brightness: brightness, surface: color)
      .harmonized();

  final bool isDark = brightness == Brightness.dark;

  return baseTheme.copyWith(
    brightness: brightness,
    colorScheme: harmonizedColorScheme,
    // Modern minimalist typography
    textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
    appBarTheme: _buildAppBarTheme(
      color,
      harmonizedColorScheme?.onSurface,
      edgeToEdgeAvailable,
      brightness,
      harmonizedColorScheme,
    ),
    primaryColor: nimbusAccent,
    canvasColor: color,
    scaffoldBackgroundColor: color,
    cardTheme: _buildCardTheme(color, harmonizedColorScheme),
    bottomSheetTheme: _buildBottomSheetTheme(color, harmonizedColorScheme),
    navigationRailTheme: baseTheme.navigationRailTheme.copyWith(
      backgroundColor: color,
      selectedIconTheme: const IconThemeData(color: nimbusAccent),
      unselectedIconTheme: IconThemeData(
        color: harmonizedColorScheme?.onSurface.withOpacity(0.5),
      ),
    ),
    navigationBarTheme: _buildNavigationBarTheme(color, harmonizedColorScheme),
    inputDecorationTheme: _buildInputDecorationTheme(),
  );
}

AppBarTheme _buildAppBarTheme(
  Color? color,
  Color? onSurfaceColor,
  bool edgeToEdgeAvailable,
  Brightness brightness,
  ColorScheme? colorScheme,
) => AppBarTheme(
  backgroundColor: color,
  foregroundColor: onSurfaceColor,
  shadowColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  centerTitle: true,
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarIconBrightness: brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light,
    statusBarColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: brightness == Brightness.light
        ? Brightness.dark
        : Brightness.light,
    systemNavigationBarColor: edgeToEdgeAvailable ? Colors.transparent : color,
  ),
);

CardThemeData _buildCardTheme(Color? color, ColorScheme? colorScheme) {
  final bool isDark = color == darkColor || color == oledColor;
  return CardThemeData(
    color: color,
    surfaceTintColor: Colors.transparent,
    // Thin borders instead of heavy shadows for a minimalist look
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        width: 1,
      ),
    ),
    shadowColor: Colors.transparent,
    elevation: 0,
  );
}

BottomSheetThemeData _buildBottomSheetTheme(
  Color? color,
  ColorScheme? colorScheme,
) => BottomSheetThemeData(
  backgroundColor: color,
  surfaceTintColor: Colors.transparent,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
);

NavigationBarThemeData _buildNavigationBarTheme(
  Color? color,
  ColorScheme? colorScheme,
) => NavigationBarThemeData(
  backgroundColor: color,
  surfaceTintColor: Colors.transparent,
  indicatorColor: nimbusAccent.withOpacity(0.15),
  labelTextStyle: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: nimbusAccent,
      );
    }
    return TextStyle(
      fontSize: 12,
      color: colorScheme?.onSurface.withOpacity(0.6),
    );
  }),
  iconTheme: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return const IconThemeData(color: nimbusAccent);
    }
    return IconThemeData(color: colorScheme?.onSurface.withOpacity(0.6));
  }),
);

InputDecorationTheme _buildInputDecorationTheme() => InputDecorationTheme(
  labelStyle: WidgetStateTextStyle.resolveWith(
    (Set<WidgetState> states) => const TextStyle(fontSize: 14),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: InputBorder.none,
  focusedBorder: InputBorder.none,
  enabledBorder: InputBorder.none,
);
