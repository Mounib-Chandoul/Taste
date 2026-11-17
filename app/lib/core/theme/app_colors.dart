import 'package:flutter/material.dart';

/// "Rice Desktop / Tokyo Night Pixel" palette.
///
/// Defined as a [ThemeExtension] so colors can be accessed via
/// `Theme.of(context).extension<AppColors>()!` and swapped at runtime
/// (e.g. live accent picker).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    this.background = const Color(0xFFB4B4EA),
    this.gridLine = const Color(0xFF8E8EC7),
    this.card = const Color(0xFF1A1B2E),
    this.cardElevated = const Color(0xFF24263D),
    this.border = const Color(0xFF3B3F5C),
    this.hardShadow = const Color(0xFF0F1020),
    this.textPrimary = const Color(0xFFC0CAF5),
    this.textSecondary = const Color(0xFF7982A9),
    this.cyan = const Color(0xFF7DCFFF),
    this.purple = const Color(0xFFBB9AF7),
    this.blue = const Color(0xFF7AA2F7),
    this.green = const Color(0xFF9ECE6A),
    this.yellow = const Color(0xFFE0AF68),
    this.red = const Color(0xFFF7768E),
    this.accent = const Color(0xFF7DCFFF),
  });

  /// Soft lavender canvas behind the bento grid.
  final Color background;

  /// Slightly darker lavender used for the sketched grid overlay.
  final Color gridLine;

  /// Primary dark navy card surface.
  final Color card;

  /// Elevated/inner card surface.
  final Color cardElevated;

  /// Thick card and control border.
  final Color border;

  /// Opaque offset shadow color (no blur) for the neo-brutalist depth.
  final Color hardShadow;

  final Color textPrimary;
  final Color textSecondary;

  /// Accent family.
  final Color cyan;
  final Color purple;
  final Color blue;
  final Color green;
  final Color yellow;
  final Color red;

  /// Active accent (switchable at runtime from settings).
  final Color accent;

  /// Default palette instance.
  static const AppColors dark = AppColors();

  /// Convenience list for rotating accent tiles.
  List<Color> get accentCycle => [cyan, purple, blue, green, yellow, red];

  AppColors copyWithAccent(Color newAccent) => copyWith(accent: newAccent);

  @override
  AppColors copyWith({
    Color? background,
    Color? gridLine,
    Color? card,
    Color? cardElevated,
    Color? border,
    Color? hardShadow,
    Color? textPrimary,
    Color? textSecondary,
    Color? cyan,
    Color? purple,
    Color? blue,
    Color? green,
    Color? yellow,
    Color? red,
    Color? accent,
  }) {
    return AppColors(
      background: background ?? this.background,
      gridLine: gridLine ?? this.gridLine,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      border: border ?? this.border,
      hardShadow: hardShadow ?? this.hardShadow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cyan: cyan ?? this.cyan,
      purple: purple ?? this.purple,
      blue: blue ?? this.blue,
      green: green ?? this.green,
      yellow: yellow ?? this.yellow,
      red: red ?? this.red,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      gridLine: l(gridLine, other.gridLine),
      card: l(card, other.card),
      cardElevated: l(cardElevated, other.cardElevated),
      border: l(border, other.border),
      hardShadow: l(hardShadow, other.hardShadow),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      cyan: l(cyan, other.cyan),
      purple: l(purple, other.purple),
      blue: l(blue, other.blue),
      green: l(green, other.green),
      yellow: l(yellow, other.yellow),
      red: l(red, other.red),
      accent: l(accent, other.accent),
    );
  }
}

/// Handy accessor: `context.colors`.
extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
