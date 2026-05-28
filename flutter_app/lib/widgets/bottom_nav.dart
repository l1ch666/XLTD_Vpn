import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Phone-style bottom navigation bar.
class BottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const BottomNav({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  static const _items = <_NavSpec>[
    _NavSpec(Icons.home_rounded, 'Главная'),
    _NavSpec(Icons.layers_rounded, 'Профили'),
    _NavSpec(Icons.swap_vert_rounded, 'Трафик'),
    _NavSpec(Icons.tune_rounded, 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            _BottomItem(
              spec: _items[i],
              active: i == activeIndex,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavSpec {
  final IconData icon;
  final String label;
  const _NavSpec(this.icon, this.label);
}

class _BottomItem extends StatelessWidget {
  final _NavSpec spec;
  final bool active;
  final VoidCallback onTap;

  const _BottomItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              spec.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
