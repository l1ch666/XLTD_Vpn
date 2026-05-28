import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_status.dart';
import '../models/transport.dart';
import '../services/vpn_bridge.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';

/// Desktop side rail with nav items and a footer that mirrors the live
/// SOCKS / route mode / core state. Matches the rail in xltd design.html.
class SideNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelect;

  const SideNav({
    super.key,
    required this.activeIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      width: 220,
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'XLTD VPN',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _NavItem(
            label: 'Главная',
            icon: Icons.home_rounded,
            active: activeIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            label: 'Профили',
            icon: Icons.layers_rounded,
            active: activeIndex == 1,
            onTap: () => onSelect(1),
          ),
          _NavItem(
            label: 'Трафик',
            icon: Icons.swap_vert_rounded,
            active: activeIndex == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            label: 'Настройки',
            icon: Icons.tune_rounded,
            active: activeIndex == 3,
            onTap: () => onSelect(3),
          ),
          _NavItem(
            label: 'Runtime log',
            icon: Icons.notes_rounded,
            active: activeIndex == 4,
            onTap: () => onSelect(4),
          ),
          const Spacer(),
          _Footer(app: app),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.label,
    required this.icon,
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
        ? AppColors.text
        : (_hover ? AppColors.text : AppColors.textMuted);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 2, 12, 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (active)
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              else
                const SizedBox(width: 3),
              const SizedBox(width: 12),
              Icon(widget.icon, size: 16, color: color),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
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
      VpnState.connected =>
        ('подключён', AppColors.ok),
      VpnState.connecting =>
        ('подключение…', AppColors.primaryLt),
      VpnState.reconnecting =>
        ('переподключение', AppColors.tagTun),
      VpnState.failed =>
        ('сбой', AppColors.err),
      VpnState.disconnected =>
        ('остановлен', AppColors.textDim),
    };
    final modes = ['SOCKS only', 'User proxy (β)', 'Full tunnel (β)'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FootLabel('SOCKS'),
          Text(
            '${VpnConstants.socksHost}:${VpnConstants.socksPort}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          const _FootLabel('РЕЖИМ'),
          Text(
            modes[app.routeMode.clamp(0, modes.length - 1)],
            style: const TextStyle(color: AppColors.text, fontSize: 11),
          ),
          const SizedBox(height: 10),
          const _FootLabel('CORE'),
          Text(
            coreLabel,
            style: TextStyle(color: coreColor, fontSize: 11),
          ),
          if (state == VpnState.connected) ...[
            const SizedBox(height: 10),
            const _FootLabel('CARRIER'),
            Text(
              '${app.telemetry.carrier ?? '—'} · '
              '${Transport.label(app.telemetry.transport ?? '')}',
              style: const TextStyle(color: AppColors.text, fontSize: 11),
            ),
          ],
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
