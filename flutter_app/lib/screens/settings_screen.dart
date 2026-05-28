import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transport.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.activeProfile;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SETTINGS',
            style: TextStyle(
              color: AppColors.textMuted,
              letterSpacing: 1.4,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Поведение туннеля',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 18),
          if (p == null)
            const Panel(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Выберите профиль на главной.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            _ProfileSummary(carrier: p.carrier, transport: p.transport),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelLabel('Маршрутизация'),
                const SizedBox(height: 8),
                _RouteOption(
                  label: 'SOCKS5 only',
                  sub: '127.0.0.1:10808 · безопасно',
                  selected: app.routeMode == 0,
                  onTap: () => app.setRouteMode(0),
                ),
                const SizedBox(height: 8),
                _RouteOption(
                  label: 'Windows user proxy',
                  sub: 'системные настройки прокси · beta',
                  selected: app.routeMode == 1,
                  onTap: () => app.setRouteMode(1),
                ),
                const SizedBox(height: 8),
                _RouteOption(
                  label: 'Full tunnel · Wintun',
                  sub: 'tun2socks · требует прав администратора',
                  selected: app.routeMode == 2,
                  onTap: () => app.setRouteMode(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelLabel('Канал'),
                const SizedBox(height: 8),
                Text(
                  'Сейчас активен ${Transport.label(p?.transport ?? '—')}. '
                  'Multipath/SEI lanes больше не используются — стабильный '
                  'one-channel режим.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final String carrier;
  final String transport;
  const _ProfileSummary({required this.carrier, required this.transport});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.ok,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$carrier · ${Transport.label(transport)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          const Icon(Icons.tune_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 4),
          const Text(
            'актив. профиль',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _RouteOption({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.06)
              : AppColors.bgAlt,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
