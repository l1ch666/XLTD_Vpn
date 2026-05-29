import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../models/transport.dart';
import '../services/formatters.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'app_icon.dart';

/// Windows dashboard hero — a horizontal status card.
///
/// Matches `_design_drop/drop2/windows` `.statusrow`: left column has a pill
/// badge, a big ↓ speed read-out and a one-line detail string; the right column
/// has the primary Stop/Connect pill button and a session summary.
class StatusRow extends StatelessWidget {
  final TelemetrySnapshot telemetry;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const StatusRow({
    super.key,
    required this.telemetry,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final state = telemetry.state;
    final connected = state == VpnState.connected;
    final rx = splitRate(telemetry.rxBps);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _StateBadge(state: state),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      '↓',
                      style: TextStyle(
                        fontFamily: kFontMono,
                        color: AppColors.ok,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rx.value,
                      style: const TextStyle(
                        fontFamily: kFontMono,
                        color: Colors.white,
                        fontSize: 46,
                        height: 0.9,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rx.unit,
                      style: const TextStyle(
                        fontFamily: kFontMono,
                        color: AppColors.textLabel,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _detailLine(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillButton(
                state: state,
                onConnect: onConnect,
                onDisconnect: onDisconnect,
              ),
              const SizedBox(height: 10),
              _SessionLine(
                bytes: telemetry.sessionRxBytes + telemetry.sessionTxBytes,
                uptime: telemetry.uptime,
                connected: connected,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailLine() {
    if (telemetry.state != VpnState.connected) {
      return const Text(
        'Туннель не активен — выбери профиль и подключись.',
        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      );
    }
    final carrier = telemetry.carrier ?? 'olcRTC';
    final transport = Transport.label(telemetry.transport ?? '');
    final latency = formatLatency(telemetry.latencyMs);
    final tx = formatRate(telemetry.txBps);
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$carrier · '),
          TextSpan(
            text: transport,
            style: const TextStyle(
              color: AppColors.primaryLt,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: ' · $latency · ↑ $tx'),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final VpnState state;
  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      VpnState.connected => ('TUNNEL ACTIVE', AppColors.ok),
      VpnState.connecting => ('CONNECTING', AppColors.primaryLt),
      VpnState.reconnecting => ('RECONNECTING', AppColors.primaryLt),
      VpnState.failed => ('FAILED', AppColors.warn),
      VpnState.disconnected => ('STOPPED', AppColors.textLabel),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: kFontMono,
              fontSize: 10.5,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final VpnState state;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _PillButton({
    required this.state,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = state == VpnState.connected || state == VpnState.reconnecting;
    final busy = state == VpnState.connecting;

    final label = switch (state) {
      VpnState.connected => 'Stop',
      VpnState.reconnecting => 'Stop',
      VpnState.connecting => 'Подключение…',
      VpnState.failed => 'Повторить',
      VpnState.disconnected => 'Подключить',
    };

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.textSecondary),
            ),
          )
        else
          AppIcon(
            isOn ? 'ic_stop.svg' : 'ic_power.svg',
            size: 14,
            color: isOn ? AppColors.vp8 : Colors.white,
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: kFontSans,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isOn ? AppColors.vp8 : Colors.white,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: busy ? null : (isOn ? onDisconnect : onConnect),
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
        decoration: BoxDecoration(
          color: isOn ? AppColors.surface : null,
          gradient: isOn
              ? null
              : const LinearGradient(colors: AppColors.connectGradient),
          border: isOn ? Border.all(color: AppColors.line) : null,
          borderRadius: BorderRadius.circular(99),
        ),
        child: child,
      ),
    );
  }
}

class _SessionLine extends StatelessWidget {
  final int bytes;
  final Duration uptime;
  final bool connected;
  const _SessionLine({
    required this.bytes,
    required this.uptime,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return const Text(
        'СЕССИЯ —',
        style: TextStyle(
          fontFamily: kFontMono,
          fontSize: 10.5,
          color: AppColors.textLabel,
          letterSpacing: 0.6,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: kFontMono,
          fontSize: 10.5,
          color: AppColors.textLabel,
          letterSpacing: 0.4,
        ),
        children: [
          const TextSpan(text: 'Сессия '),
          TextSpan(
            text: formatBytes(bytes),
            style: const TextStyle(color: AppColors.textTertiary),
          ),
          const TextSpan(text: ' · '),
          TextSpan(
            text: formatDuration(uptime),
            style: const TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
