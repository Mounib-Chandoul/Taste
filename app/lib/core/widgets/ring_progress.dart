import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular progress ring with rounded stroke caps and neon color.
///
/// Used for volume, playback progress, listening goals, and "daily minutes"
/// style stats. Animates smoothly when [value] changes.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    this.size = 96,
    this.strokeWidth = 10,
    this.color,
    this.trackColor,
    this.backgroundColor,
    this.child,
    this.startAngle = -math.pi / 2,
    this.animate = true,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutBack,
  });

  /// Progress in [0, 1]. Values are clamped.
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;

  /// Optional fill inside the ring.
  final Color? backgroundColor;

  /// Center content (e.g. percentage, icon, time label).
  final Widget? child;

  /// Start angle in radians; defaults to 12 o'clock.
  final double startAngle;
  final bool animate;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = color ?? colors.accent;
    final track = trackColor ?? colors.border.withValues(alpha: 0.45);
    final clamped = value.clamp(0.0, 1.0);

    Widget paint(double v) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: v,
            strokeWidth: strokeWidth,
            color: active,
            trackColor: track,
            backgroundColor: backgroundColor,
            startAngle: startAngle,
          ),
          child: child != null ? Center(child: child) : null,
        ),
      );
    }

    if (!animate) return RepaintBoundary(child: paint(clamped));

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: duration,
        curve: curve,
        builder: (context, v, _) => paint(v),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    required this.startAngle,
    this.backgroundColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Color? backgroundColor;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (backgroundColor != null) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = backgroundColor!
          ..style = PaintingStyle.fill,
      );
    }

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Full track circle.
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (value <= 0) return;

    final sweep = (math.pi * 2) * value.clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Subtle neon glow layer behind the main stroke.
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..isAntiAlias = true;

    canvas.drawArc(rect, startAngle, sweep, false, glowPaint);
    canvas.drawArc(rect, startAngle, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.value != value ||
        old.strokeWidth != strokeWidth ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.backgroundColor != backgroundColor ||
        old.startAngle != startAngle;
  }
}
