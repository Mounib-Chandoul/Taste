import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the "Rice Desktop / Tokyo Night Pixel" [ThemeData].
///
/// Material 3 is disabled in favor of the custom design system; we still use
/// Flutter's base theming for text/scroll defaults and widget fallbacks.
class AppTheme {
  const AppTheme._();

  static ThemeData build({Color? accent}) {
    final colors = accent == null ? AppColors.dark : AppColors.dark.copyWithAccent(accent);
    const pixel = AppTypography.pixelFamily;
    const mono = AppTypography.monoFamily;

    final baseText = ThemeData.dark().textTheme.apply(
          fontFamily: mono,
          bodyColor: colors.textPrimary,
          displayColor: colors.textPrimary,
        );

    TextStyle pixelStyle(double size, {double height = 1.2}) => TextStyle(
          fontFamily: pixel,
          fontSize: size,
          color: colors.textPrimary,
          height: height,
        );

    TextStyle monoStyle(double size, {Color? color, double height = 1.4}) =>
        TextStyle(
          fontFamily: mono,
          fontSize: size,
          color: color ?? colors.textPrimary,
          height: height,
        );

    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.background,
      primaryColor: colors.accent,
      canvasColor: colors.card,
      cardColor: colors.card,
      dividerColor: colors.border,
      shadowColor: colors.hardShadow,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[colors],
      colorScheme: ColorScheme.dark(
        brightness: Brightness.dark,
        primary: colors.accent,
        onPrimary: colors.card,
        secondary: colors.purple,
        onSecondary: colors.card,
        surface: colors.card,
        onSurface: colors.textPrimary,
        error: colors.red,
        onError: colors.card,
      ),
      textTheme: baseText.copyWith(
        headlineLarge: pixelStyle(28, height: 1.1),
        headlineMedium: pixelStyle(20),
        titleLarge: pixelStyle(16, height: 1.25),
        titleMedium: pixelStyle(13, height: 1.25),
        titleSmall: pixelStyle(10),
        bodyLarge: monoStyle(14),
        bodyMedium: monoStyle(13),
        bodySmall: monoStyle(11, color: colors.textSecondary, height: 1.35),
        labelLarge: monoStyle(12).copyWith(fontWeight: FontWeight.w600),
        labelSmall: pixelStyle(9).copyWith(color: colors.textSecondary),
      ),
      iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colors.textPrimary,
        titleTextStyle: pixelStyle(14),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(colors.border),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(8),
      ),
    );
  }
}
