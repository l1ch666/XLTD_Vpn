import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'app_icon.dart';

/// Phone-style bottom navigation bar.
///
/// Matches `_design_drop/drop1/android` — bg #10131A, 1dp top border #171A20,
/// padding 10/8. Each item is an SVG nav glyph over a 9sp bold UPPERCASE
/// label; active = primary, inactive = border_dim.
class BottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const BottomNav({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  static const _labels = ['ГЛАВНАЯ', 'ПРОФИЛИ', 'ТРАФИК', 'НАСТРОЙКИ'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(top: BorderSide(color: Color(0xFF171A20))),
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: _BottomItem(
                  tab: i,
                  label: _labels[i],
                  active: i == activeIndex,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final int tab;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.tab,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.borderDim;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcon.navAsset(tab), size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 0.95,
            ),
          ),
        ],
      ),
    );
  }
}
