import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Small bordered square/capsule button with hard shadow and press animation.
///
/// Used for transport controls, icon tiles, chips, and quick links. The press
/// collapses the shadow and shifts the button toward it.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.shadowColor,
    this.size,
    this.width,
    this.height,
    this.padding,
    this.radius = 10,
    this.borderWidth = 2.5,
    this.shadowOffset = const Offset(4, 4),
    this.selected = false,
    this.tooltip,
    this.semanticLabel,
  });

  /// Icon, text, or any compact content.
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final Color? shadowColor;

  /// Square size shortcut (sets both width and height).
  final double? size;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double borderWidth;
  final Offset shadowOffset;

  /// Keeps the button in its pressed/active visual state.
  final bool selected;
  final String? tooltip;
  final String? semanticLabel;

  /// Convenience factory for an icon tile.
  factory PixelButton.icon({
    Key? key,
    required IconData icon,
    VoidCallback? onTap,
    double iconSize = 20,
    Color? iconColor,
    Color? color,
    Color? borderColor,
    double size = 44,
    double radius = 10,
    bool selected = false,
    Offset shadowOffset = const Offset(4, 4),
    String? tooltip,
  }) {
    return PixelButton(
      key: key,
      onTap: onTap,
      color: color,
      borderColor: borderColor,
      size: size,
      radius: radius,
      selected: selected,
      shadowOffset: shadowOffset,
      tooltip: tooltip,
      semanticLabel: tooltip,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }

  /// Convenience factory for a text label button.
  factory PixelButton.label({
    Key? key,
    required String label,
    VoidCallback? onTap,
    Color? color,
    Color? textColor,
    Color? borderColor,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    bool selected = false,
  }) {
    return PixelButton(
      key: key,
      onTap: onTap,
      color: color,
      borderColor: borderColor,
      padding: padding,
      selected: selected,
      child: Text(label, style: AppTypography.label(color: textColor)),
    );
  }

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;
  bool get _isPressed => widget.selected || _down;

  void _setDown(bool v) {
    if (!_interactive) return;
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = widget.color ?? colors.cardElevated;
    final border = widget.borderColor ?? colors.border;
    final shadow = widget.shadowColor ?? colors.hardShadow;
    final full = widget.shadowOffset;
    final currentOffset = _isPressed ? Offset.zero : full;

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: _isPressed ? Curves.easeIn : Curves.easeOutBack,
      transform: Matrix4.translationValues(
        _isPressed ? full.dx : 0,
        _isPressed ? full.dy : 0,
        0,
      ),
      width: widget.size ?? widget.width,
      height: widget.size ?? widget.height,
      padding: widget.padding ??
          (widget.size != null ? EdgeInsets.zero : const EdgeInsets.all(8)),
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
      alignment: Alignment.center,
      child: IconTheme.merge(
        data: IconThemeData(color: colors.textPrimary),
        child: widget.child,
      ),
    );

    if (_interactive) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: content,
      );
    }

    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }
    if (widget.semanticLabel != null) {
      content = Semantics(
        button: _interactive,
        label: widget.semanticLabel,
        child: content,
      );
    }
    return content;
  }
}
