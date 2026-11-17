import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft lavender canvas with a hand-drawn, slightly wobbly grid overlay.
///
/// The subtle jitter on each line segment gives the sketched "rice desktop"
/// feel. Wrapped in a [RepaintBoundary] when used as a large backdrop to
/// keep painters 60fps-friendly.
class GridBackground extends StatelessWidget {
  const GridBackground({
    super.key,
    this.child,
    this.cellSize = 40,
    this.strokeWidth = 1.5,
    this.jitter = 0.8,
    this.seed = 7,
  });

  final Widget? child;
  final double cellSize;
  final double strokeWidth;

  /// Max perpendicular offset in logical pixels for the sketched wobble.
  final double jitter;

  /// Stable seed so the grid doesn't "boil" on rebuilds.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GridPainter(
          background: colors.background,
          lineColor: colors.gridLine,
          cellSize: cellSize,
          strokeWidth: strokeWidth,
          jitter: jitter,
          seed: seed,
        ),
        child: child,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.background,
    required this.lineColor,
    required this.cellSize,
    required this.strokeWidth,
    required this.jitter,
    required this.seed,
  });

  final Color background;
  final Color lineColor;
  final double cellSize;
  final double strokeWidth;
  final double jitter;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    // Draw segmented lines with small perpendicular jitter so they look
    // hand-sketched rather than perfect.
    const segment = 20.0;

    // Vertical lines.
    int col = 0;
    for (double x = 0; x <= size.width + 0.5; x += cellSize, col++) {
      final path = Path();
      double y = 0;
      bool first = true;
      while (y <= size.height) {
        final j = _jitter(col, (y / segment).floor(), 1);
        final px = x + j;
        if (first) {
          path.moveTo(px, y);
          first = false;
        } else {
          path.lineTo(px, y);
        }
        y += segment;
      }
      canvas.drawPath(path, paint);
    }

    // Horizontal lines.
    int row = 0;
    for (double y = 0; y <= size.height + 0.5; y += cellSize, row++) {
      final path = Path();
      double x = 0;
      bool first = true;
      while (x <= size.width) {
        final j = _jitter(row, (x / segment).floor(), 2);
        final py = y + j;
        if (first) {
          path.moveTo(x, py);
          first = false;
        } else {
          path.lineTo(x, py);
        }
        x += segment;
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Deterministic pseudo-random jitter in [-jitter, +jitter].
  double _jitter(int a, int b, int salt) {
    var h = seed;
    h = 0x1fffffff & (h + a * 374761393);
    h = 0x1fffffff & (h + b * 668265263);
    h = 0x1fffffff & (h + salt * 1274126177);
    h = (h ^ (h >> 13)) * 1103515245;
    h = 0x1fffffff & (h ^ (h >> 16));
    final t = (h & 0xffff) / 0xffff; // 0..1
    return (t * 2 - 1) * jitter;
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) {
    return old.background != background ||
        old.lineColor != lineColor ||
        old.cellSize != cellSize ||
        old.strokeWidth != strokeWidth ||
        old.jitter != jitter ||
        old.seed != seed;
  }
}
