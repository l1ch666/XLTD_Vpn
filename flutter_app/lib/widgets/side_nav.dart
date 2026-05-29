import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_status.dart';
import '../services/vpn_bridge.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

/// Desktop side rail (220px) with SVG nav items and a mono footer mirroring the
/// live SOCKS endpoint / route mode / core state. Matches `_design_drop/drop2`.
class SideNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const SideNav({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  static const _labels = ['Главная', 'Профили', 'Трафик', 'Настройки', 'Runtime log'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      width: 220,
      color: AppColors.navBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                fontFamily: kFontMono,
                color: AppColors.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _labels.length; i++)
            _NavItem(
              label: _labels[i],
              tab: i,
              active: activeIndex == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          _Footer(app: app),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final int tab;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.label,
    required this.tab,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final color = active
        ? AppColors.primaryLt
        : (_hover ? AppColors.textTertiary : AppColors.textMuted);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
          decoration: BoxDecoration(
            color: active
                ? AppColors.surface
                : (_hover ? AppColors.surfaceAlt : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 2px inset active bar
                Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcon.navAsset(widget.tab),
                        size: 16,
                        color: color,
                      ),
                      const SizedBox(width: 11),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontFamily: kFontSans,
                          color: color,
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final AppState app;
  const _Footer({required this.app});

  @override
  Widget build(BuildContext context) {
    final state = app.telemetry.state;
    final (coreLabel, coreColor) = switch (state) {
      VpnState.connected => ('подключён', AppColors.ok),
      VpnState.connecting => ('подключение…', AppColors.primaryLt),
      VpnState.reconnecting => ('переподключение', AppColors.primaryLt),
      VpnState.failed => ('сбой', AppColors.warn),
      VpnState.disconnected => ('остановлен', AppColors.textDim),
    };
    const modes = ['Local SOCKS', 'User proxy · β', 'Full tunnel · β'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FootLabel('SOCKS'),
          Text(
            '${VpnConstants.socksHost}:${VpnConstants.socksPort}',
            style: const TextStyle(
              color: AppColors.primaryLt,
              fontSize: 11,
              fontFamily: kFontMono,
            ),
          ),
          const SizedBox(height: 10),
          const _FootLabel('MODE'),
          Text(
            modes[app.routeMode.clamp(0, modes.length - 1)],
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontFamily: kFontMono,
            ),
          ),
          const SizedBox(height: 10),
          const _FootLabel('CORE'),
          Text(
            coreLabel,
            style: TextStyle(
              color: coreColor,
              fontSize: 11,
              fontFamily: kFontMono,
            ),
          ),
        ],
      ),
    );
  }
}

class _FootLabel extends StatelessWidget {
  final String text;
  const _FootLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: kFontMono,
          color: AppColors.textFaint,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
