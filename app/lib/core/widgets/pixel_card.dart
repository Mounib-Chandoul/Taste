import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Neo-brutalist card: rounded rectangle, thick border, hard offset shadow.
///
/// Signature interaction: on press the shadow collapses and the card shifts
/// toward it (snappy, slightly steppy). Reusable everywhere in the theme.
class PixelCard extends StatefulWidget {
  const PixelCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.shadowColor,
    this.padding,
    this.margin,
    this.radius = 16,
    this.borderWidth = 2.5,
    this.shadowOffset = const Offset(6, 6),
    this.pressed = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double borderWidth;

  /// Hard shadow offset (no blur). Collapses to zero when pressed.
  final Offset shadowOffset;

  /// Force pressed/active state (e.g. selected nav item).
  final bool pressed;

  @override
  State<PixelCard> createState() => _PixelCardState();
}

class _PixelCardState extends State<PixelCard> {
  bool _down = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;
  bool get _isPressed => widget.pressed || _down;

  void _setDown(bool v) {
    if (!_interactive) return;
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = widget.color ?? colors.card;
    final border = widget.borderColor ?? colors.border;
    final shadow = widget.shadowColor ?? colors.hardShadow;
    final full = widget.shadowOffset;
    final currentOffset = _isPressed ? Offset.zero : full;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: _isPressed ? Curves.easeIn : Curves.easeOutBack,
      transform: Matrix4.translationValues(
        _isPressed ? full.dx : 0,
        _isPressed ? full.dy : 0,
        0,
      ),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border, width: widget.borderWidth),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: currentOffset,
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((widget.radius - widget.borderWidth)
            .clamp(0.0, widget.radius)),
        child: Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: widget.child,
        ),
      ),
    );

    if (!_interactive) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!.call();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      child: card,
    );
  }
}
