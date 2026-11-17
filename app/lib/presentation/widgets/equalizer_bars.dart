import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Pixel-style blocky equalizer bars in accent colors.
///
/// Animates while [active] is true; settles to low bars when paused.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    this.active = true,
    this.barCount = 5,
    this.width = 28,
    this.height = 20,
    this.gap = 2,
    this.colors,
  });

  final bool active;
  final int barCount;
  final double width;
  final double height;
  final double gap;
  final List<Color>? colors;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0.15;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.colors ??
        [
          context.colors.cyan,
          context.colors.purple,
          context.colors.green,
          context.colors.yellow,
          context.colors.red,
        ];
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _BarsPainter(
                t: _ctrl.value,
                active: widget.active,
                barCount: widget.barCount,
                gap: widget.gap,
                colors: palette,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.t,
    required this.active,
    required this.barCount,
    required this.gap,
    required this.colors,
  });

  final double t;
  final bool active;
  final int barCount;
  final double gap;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final totalGap = gap * (barCount - 1);
    final barW = ((size.width - totalGap) / barCount).clamp(2.0, size.width);
    const step = 3.0; // blocky "pixel" steps

    for (var i = 0; i < barCount; i++) {
      final phase = (t * 2 * math.pi) + i * 1.3;
      final wave = (math.sin(phase) + 1) / 2; // 0..1
      final wave2 = (math.sin(phase * 1.7 + 0.8) + 1) / 2;
      final raw = active ? (0.25 + 0.75 * (0.6 * wave + 0.4 * wave2)) : 0.18;
      final stepped = (raw * (size.height / step)).round() * step;
      final h = stepped.clamp(step, size.height);
      final x = i * (barW + gap);
      final y = size.height - h;
      final rect = Rect.fromLTWH(x, y, barW, h);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
      // pixel highlight cap
      canvas.drawRect(
        Rect.fromLTWH(x, y, barW, step.clamp(1.0, h)),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) {
    return old.t != t ||
        old.active != active ||
        old.barCount != barCount ||
        old.gap != gap;
  }
}
