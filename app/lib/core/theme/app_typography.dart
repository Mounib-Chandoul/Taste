import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography for the Rice/Tokyo Night Pixel design system.
///
/// - Headings / titles / big labels: Silkscreen (pixel font).
/// - Body / metadata / timestamps: JetBrains Mono.
///
/// Both typefaces are bundled in `assets/fonts`, so the look is identical
/// online and offline. No runtime Google Fonts fetch is involved.
class AppTypography {
  const AppTypography._();

  static const String pixelFamily = 'Silkscreen';
  static const String monoFamily = 'JetBrainsMono';

  static TextStyle pixel({
    double size = 12,
    Color? color,
    double? height,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: pixelFamily,
      fontSize: size,
      color: color ?? AppColors.dark.textPrimary,
      height: height,
      fontWeight: weight,
    );
  }

  static TextStyle mono({
    double size = 13,
    Color? color,
    double? height,
    FontWeight weight = FontWeight.w400,
    FontStyle fontStyle = FontStyle.normal,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      color: color ?? AppColors.dark.textSecondary,
      height: height,
      fontWeight: weight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }

  /// Large clock / hero pixel display.
  static TextStyle display({Color? color}) =>
      pixel(size: 28, color: color, height: 1.1);

  /// Section/card titles.
  static TextStyle title({Color? color}) =>
      pixel(size: 14, color: color, height: 1.25);

  /// Smaller pixel labels (buttons, chips).
  static TextStyle label({Color? color}) =>
      pixel(size: 10, color: color, height: 1.2);

  /// Primary body/metadata.
  static TextStyle body({Color? color}) =>
      mono(size: 13, color: color ?? AppColors.dark.textPrimary, height: 1.4);

  /// Secondary/meta/timestamps.
  static TextStyle caption({Color? color}) =>
      mono(size: 11, color: color ?? AppColors.dark.textSecondary, height: 1.35);

  /// Terminal prompt decorative header, e.g. `user@aesthetic ~ $ now_playing`.
  static TextStyle prompt({Color? color}) => mono(
        size: 11,
        color: color ?? AppColors.dark.green,
        height: 1.3,
        letterSpacing: 0.2,
      );
}

/// Pixel-styled text widget with common defaults.
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.style,
    this.size,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final double? size;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTypography.title(color: color);
    return Text(
      text,
      style: size != null ? base.copyWith(fontSize: size) : base,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

/// Monospaced text widget for metadata/body.
class MonoText extends StatelessWidget {
  const MonoText(
    this.text, {
    super.key,
    this.style,
    this.size,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final double? size;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? AppTypography.body(color: color);
    return Text(
      text,
      style: size != null ? base.copyWith(fontSize: size) : base,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
