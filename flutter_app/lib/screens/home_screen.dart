import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/connection_status.dart';
import '../models/transport.dart';
import '../services/formatters.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../widgets/connect_button.dart';
import '../widgets/event_row.dart';
import '../widgets/hero_status.dart';
import '../widgets/metric_card.dart';
import '../widgets/panel.dart';
import '../widgets/profile_row.dart';
import '../widgets/status_row.dart';
import '../widgets/transport_chip.dart';
import 'profiles_screen.dart';

/// Main dashboard. Layout adapts to wide (Windows desktop) vs. narrow (Android).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return SingleChildScrollView(
      padding: isWide
          ? const EdgeInsets.fromLTRB(24, 22, 24, 28)
          : const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: isWide ? _WideLayout(app: app) : _NarrowLayout(app: app),
    );
  }
}

// ── Wide (Windows desktop) ─────────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final AppState app;
  const _WideLayout({required this.app});

  @override
  Widget build(BuildContext context) {
    final active = app.telemetry.transport ?? app.activeProfile?.transport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: _PageHeading()),
            TransportChipsRow(
              activeTransport: active,
              alignment: MainAxisAlignment.end,
              onSelect: (t) async {
                if (app.activeProfile == null) return;
                await app.switchTransport(t);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        StatusRow(
          telemetry: app.telemetry,
          onConnect: app.connect,
          onDisconnect: app.disconnect,
        ),
        const SizedBox(height: 14),
        _MetricsGrid(t: app.telemetry, showSpark: true),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _ProfilesPanel(app: app)),
            const SizedBox(width: 14),
            Expanded(flex: 4, child: _EventsPanel(app: app, limit: 10)),
          ],
        ),
        const SizedBox(height: 14),
        _RouteModeCard(app: app),
      ],
    );
  }
}

/// Windows dashboard heading: mono eyebrow + serif "Канал жив." headline.
class _PageHeading extends StatelessWidget {
  const _PageHeading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'DASHBOARD',
          style: TextStyle(
            fontFamily: kFontMono,
            color: AppColors.textFaint,
            letterSpacing: 1.4,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: kFontSerif,
              fontSize: 30,
              height: 1.05,
            ),
            children: [
              TextSpan(
                text: 'Канал ',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: 'жив.',
                style: TextStyle(
                  color: AppColors.ok,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Metrics grid (4-wide spark on Windows, 2×2 plain on Android) ────────

class _MetricsGrid extends StatelessWidget {
  final TelemetrySnapshot t;
  final bool showSpark;
  const _MetricsGrid({required this.t, required this.showSpark});

  @override
  Widget build(BuildContext context) {
    final rx = splitRate(t.rxBps);
    final tx = splitRate(t.txBps);
    final transportLabel = Transport.label(t.transport ?? '');
    final carrier = t.carrier ?? 'olcRTC';

    final cards = <MetricCard>[
      MetricCard(
        label: '↓ Входящий',
        value: rx.value,
        unit: rx.unit,
        subLabel: transportLabel.isEmpty ? 'один канал' : transportLabel,
        spark: const [0.2, 0.5, 0.4, 0.7, 0.6, 0.8, 0.9, 1.0],
        showSpark: showSpark,
      ),
      MetricCard(
        label: '↑ Исходящий',
        value: tx.value,
        unit: tx.unit,
        subLabel: carrier,
        spark: const [0.2, 0.3, 0.3, 0.4, 0.5, 0.5, 0.7, 0.6],
        showSpark: showSpark,
      ),
      MetricCard(
        label: 'Задержка',
        value: t.latencyMs >= 0 ? '${t.latencyMs}' : '—',
        unit: t.latencyMs >= 0 ? 'ms' : '',
        subLabel: 'SOCKS probe',
        spark: const [0.4, 0.5, 0.3, 0.5, 0.4, 0.6, 0.5, 0.4],
        showSpark: showSpark,
      ),
      MetricCard(
        label: 'Аптайм',
        value: formatDuration(t.uptime),
        unit: '',
        subLabel: 'сессия',
        spark: const [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
        showSpark: showSpark,
      ),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      final cols = showSpark && c.maxWidth >= 760 ? 4 : 2;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cards) SizedBox(width: w, child: card),
        ],
      );
    });
  }
}

// ── Profiles + events panels ────────────────────────────────────────────

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
              const PanelLabel('Серверы'),
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
  final int limit;
  const _EventsPanel({required this.app, this.limit = 5});

  @override
  Widget build(BuildContext context) {
    final events = app.events.toList().reversed.take(limit).toList();
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PanelLabel('События · live'),
              Spacer(),
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

// ── Route mode (Windows only) — 3 selectable cards ──────────────────────

class _RouteModeCard extends StatelessWidget {
  final AppState app;
  const _RouteModeCard({required this.app});

  static const _modes = [
    (
      title: 'Local SOCKS',
      sub: '127.0.0.1:10808',
      tag: 'default',
    ),
    (
      title: 'Windows user proxy',
      sub: 'системный прокси',
      tag: 'β',
    ),
    (
      title: 'Full tunnel · Wintun',
      sub: 'весь трафик',
      tag: 'admin',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelLabel('Режим маршрутизации'),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _modes.length; i++) ...[
                Expanded(
                  child: _RouteModeTile(
                    title: _modes[i].title,
                    sub: _modes[i].sub,
                    tag: _modes[i].tag,
                    selected: app.routeMode == i,
                    onTap: () => app.setRouteMode(i),
                  ),
                ),
                if (i < _modes.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteModeTile extends StatelessWidget {
  final String title;
  final String sub;
  final String tag;
  final bool selected;
  final VoidCallback onTap;
  const _RouteModeTile({
    required this.title,
    required this.sub,
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF15182B) : AppColors.surfaceAlt,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (selected)
                  Text(
                    '$tag · active',
                    style: const TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 9.5,
                      color: AppColors.primaryLt,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kFontMono,
                fontSize: 10,
                color: AppColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Narrow (Android) ──────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final AppState app;
  const _NarrowLayout({required this.app});

  @override
  Widget build(BuildContext context) {
    final active = app.telemetry.transport ?? app.activeProfile?.transport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileTopBar(t: app.telemetry),
        const SizedBox(height: 14),
        HeroStatus(telemetry: app.telemetry),
        const SizedBox(height: 18),
        ConnectButton(
          state: app.telemetry.state,
          onPressed: app.isConnected || app.isBusy
              ? app.disconnect
              : app.connect,
        ),
        const SizedBox(height: 16),
        TransportChipsRow(
          activeTransport: active,
          onSelect: (t) async {
            if (app.activeProfile != null) {
              await app.switchTransport(t);
            }
          },
        ),
        const SizedBox(height: 16),
        _MetricsGrid(t: app.telemetry, showSpark: false),
        const SizedBox(height: 14),
        _ProfilesPanel(app: app),
        const SizedBox(height: 14),
        _EventsPanel(app: app, limit: 5),
      ],
    );
  }
}

/// Android status bar row: "XLTD VPN" (mono muted) · "↓ rate" (mono dim).
class _MobileTopBar extends StatelessWidget {
  final TelemetrySnapshot t;
  const _MobileTopBar({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'XLTD VPN',
          style: TextStyle(
            fontFamily: kFontMono,
            fontSize: 12,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          '↓ ${formatRate(t.rxBps)}',
          style: const TextStyle(
            fontFamily: kFontMono,
            fontSize: 12,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}
