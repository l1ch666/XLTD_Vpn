import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transport.dart';
import '../services/formatters.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/metric_card.dart';
import '../widgets/panel.dart';

class TrafficScreen extends StatelessWidget {
  const TrafficScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = app.telemetry;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAFFIC',
            style: TextStyle(
              color: AppColors.textMuted,
              letterSpacing: 1.4,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Поток через туннель',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Метрики получены из TrafficStats / SOCKS — приблизительные.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (ctx, c) {
              final w = (c.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: w,
                    child: MetricCard(
                      label: 'СКАЧАНО',
                      value: formatBytes(t.sessionRxBytes).split(' ').first,
                      unit: formatBytes(t.sessionRxBytes).split(' ').last,
                      subLabel: 'за сессию',
                      spark: const [0.1, 0.3, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0],
                      sparkColor: AppColors.ok,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: MetricCard(
                      label: 'ОТПРАВЛЕНО',
                      value: formatBytes(t.sessionTxBytes).split(' ').first,
                      unit: formatBytes(t.sessionTxBytes).split(' ').last,
                      subLabel: 'за сессию',
                      spark: const [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
                      sparkColor: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelLabel('Текущая ссылка'),
                const SizedBox(height: 8),
                Text(
                  app.activeProfile == null
                      ? '—'
                      : '${app.activeProfile!.carrier} · '
                          '${Transport.label(app.activeProfile!.transport)}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  app.activeProfile?.link ?? 'выберите профиль',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'monospace',
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
