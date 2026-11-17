// Music Lab design system.
//
// A deep, cool dark palette built around blue-black "ink" surfaces,
// lit by electric blue and cyan accents. Monospaced numerals are
// reserved for times, stats and labels: the quiet, non-gimmicky tell
// of an engineer's app.

import 'package:flutter/material.dart';

/// The palette. Single source of truth - widgets reference these directly
/// instead of scattering raw Color values across files.
class Palette {
  static const ink = Color(0xFF060B18); // scaffold background
  static const surface = Color(0xFF0B1222); // bars, sheets, cards
  static const surfaceAlt = Color(0xFF111A2E); // elevated cards, fields
  static const line = Color(0xFF1B2A44); // hairline borders
  static const fg = Color(0xFFD9E8FF); // primary text
  static const dim = Color(0xFF7B90B8); // secondary text
  static const accent = Color(0xFF38BDF8); // sky blue - brand/primary
  static const violet = Color(0xFF22D3EE); // cyan - secondary highlights
  static const teal = Color(0xFF67E8F9); // bright cyan - "playing now"
  static const red = Color(0xFFF87171); // errors
}

/// Monospaced text for anything numeric or machine-flavored.
TextStyle mono(
  BuildContext context, {
  double? size,
  Color? color,
  FontWeight? weight,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: "monospace",
    fontSize: size,
    color: color ?? Palette.dim,
    fontWeight: weight,
    letterSpacing: letterSpacing ?? 0,
  );
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.accent,
    onPrimary: Palette.ink,
    secondary: Palette.violet,
    onSecondary: Palette.ink,
    tertiary: Palette.teal,
    onTertiary: Palette.ink,
    error: Palette.red,
    surface: Palette.surface,
    onSurface: Palette.fg,
    surfaceContainerHighest: Palette.surfaceAlt,
    onSurfaceVariant: Palette.dim,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.ink,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.ink,
      foregroundColor: Palette.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Palette.fg,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1),
    cardTheme: const CardThemeData(
      color: Palette.surfaceAlt,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Palette.line),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      activeTrackColor: Palette.accent,
      inactiveTrackColor: Palette.line,
      thumbColor: Palette.teal,
      overlayColor: Color(0x2938BDF8),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      showValueIndicator: ShowValueIndicator.never,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.accent,
        foregroundColor: Palette.ink,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.fg,
        side: const BorderSide(color: Palette.line),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Palette.surface,
      indicatorColor: Color(0x2638BDF8), // accent @ 15%
      height: 64,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Palette.surface,
      indicatorColor: Color(0x2638BDF8),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Palette.fg,
      unselectedLabelColor: Palette.dim,
      indicatorColor: Palette.accent,
      dividerColor: Palette.line,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.accent),
      ),
      hintStyle: const TextStyle(color: Palette.dim),
      labelStyle: const TextStyle(color: Palette.dim),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.surfaceAlt,
      contentTextStyle: TextStyle(color: Palette.fg),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.accent,
      linearTrackColor: Palette.line,
    ),
  );
}
