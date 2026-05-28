import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_status.dart';
import '../models/transport.dart';
import '../services/formatters.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/event_row.dart';
import '../widgets/hero_status.dart';
import '../widgets/metric_card.dart';
import '../widgets/panel.dart';
import '../widgets/profile_row.dart';
import '../widgets/transport_chip.dart';
import 'profiles_screen.dart';

/// Main dashboard. Layout adapts to wide (desktop) vs. narrow (phone).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      child: isWide ? _WideLayout(app: app) : _NarrowLayout(app: app),
    );
  }
}

// ── Wide (desktop) ────────────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final AppState app;
  const _WideLayout({required this.app});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeHeader(app: app),
        const SizedBox(height: 18),
        HeroStatus(
          telemetry: app.telemetry,
          onConnect: app.connect,
          onDisconnect: app.disconnect,
        ),
        const SizedBox(height: 14),
        _MetricsGrid(t: app.telemetry),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _ProfilesPanel(app: app)),
            const SizedBox(width: 14),
            Expanded(flex: 4, child: _EventsPanel(app: app)),
          ],
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final AppState app;
  const _HomeHeader({required this.app});

  @override
  Widget build(BuildContext context) {
    final active = app.telemetry.transport ?? app.activeProfile?.transport;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(child: _Greeting()),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TRANSPORT  ',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            TransportChipsRow(
              activeTransport: active,
              onSelect: (t) async {
                if (app.activeProfile == null) return;
                await app.switchTransport(t);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DASHBOARD',
          style: TextStyle(
            color: AppColors.textMuted,
            letterSpacing: 1.4,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'Канал',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'жив.',
              style: TextStyle(
                color: AppColors.ok,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.0,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final TelemetrySnapshot t;
  const _MetricsGrid({required this.t});

  @override
  Widget build(BuildContext context) {
    final rx = splitRate(t.rxBps);
    final tx = splitRate(t.txBps);
    final transportLabel = Transport.label(t.transport ?? '—');
    return LayoutBuilder(builder: (ctx, c) {
      // 4 columns wide, 2x2 narrow.
      final cols = c.maxWidth >= 800 ? 4 : 2;
      final gap = 14.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: w,
            child: MetricCard(
              label: '↓ Входящий',
              value: rx.value,
              unit: rx.unit,
              subLabel: transportLabel,
              spark: const [0.2, 0.5, 0.4, 0.7, 0.6, 0.8, 0.9, 1.0],
              sparkColor: AppColors.ok,
            ),
          ),
          SizedBox(
            width: w,
            child: MetricCard(
              label: '↑ Исходящий',
              value: tx.value,
              unit: tx.unit,
              subLabel: 'один канал',
              spark: const [0.2, 0.3, 0.3, 0.4, 0.5, 0.5, 0.7, 0.6],
              sparkColor: AppColors.primary,
            ),
          ),
          SizedBox(
            width: w,
            child: MetricCard(
              label: 'Задержка',
              value: t.latencyMs >= 0 ? '${t.latencyMs}' : '—',
              unit: 'ms',
              subLabel: 'SOCKS probe',
              spark: const [0.4, 0.5, 0.3, 0.5, 0.4, 0.6, 0.5, 0.4],
              sparkColor: AppColors.primaryLt,
            ),
          ),
          SizedBox(
            width: w,
            child: MetricCard(
              label: 'Аптайм',
              value: formatDuration(t.uptime),
              unit: '',
              subLabel: 'сессия',
              spark: const [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
              sparkColor: AppColors.textMuted,
            ),
          ),
        ],
      );
    });
  }
}

class _ProfilesPanel extends StatelessWidget {
  final AppState app;
  const _ProfilesPanel({required this.app});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PanelLabel('Профили'),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ProfilesScreen(),
                  ));
                },
                child: const Text('+ добавить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (app.profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Профилей пока нет.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final p in app.profiles) ...[
            ProfileRow(
              profile: p,
              active: p.id == app.activeProfile?.id,
              onTap: () => app.selectProfile(p),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  final AppState app;
  const _EventsPanel({required this.app});

  @override
  Widget build(BuildContext context) {
    final events = app.events.toList().reversed.take(8).toList();
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PanelLabel('События · live'),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Тишина в эфире.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final e in events) EventRow(event: e),
        ],
      ),
    );
  }
}

// ── Narrow (phone) ────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final AppState app;
  const _NarrowLayout({required this.app});

  @override
  Widget build(BuildContext context) {
    final active = app.telemetry.transport ?? app.activeProfile?.transport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Greeting(),
        const SizedBox(height: 16),
        HeroStatus(
          telemetry: app.telemetry,
          onConnect: app.connect,
          onDisconnect: app.disconnect,
        ),
        const SizedBox(height: 14),
        TransportChipsRow(
          activeTransport: active,
          onSelect: (t) async {
            if (app.activeProfile != null) {
              await app.switchTransport(t);
            }
          },
        ),
        const SizedBox(height: 14),
        _MetricsGrid(t: app.telemetry),
        const SizedBox(height: 14),
        _ProfilesPanel(app: app),
        const SizedBox(height: 14),
        _EventsPanel(app: app),
      ],
    );
  }
}
