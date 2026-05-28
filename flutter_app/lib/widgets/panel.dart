import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Default card surface: 1 px [AppColors.border] outline, 14 px radius.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  final bool selected;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 14,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.surface;
    final br = borderColor ?? (selected ? AppColors.primary : AppColors.border);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: br, width: selected ? 1.5 : 1),
    );
    final box = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: box,
    );
  }
}

/// Label printed above a card's main metric ("↓ ВХОДЯЩИЙ", "АПТАЙМ", etc.).
class PanelLabel extends StatelessWidget {
  final String text;
  const PanelLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.6,
      ),
    );
  }
}
