import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../models/transport.dart';
import '../services/formatters.dart';
import '../theme/colors.dart';
import 'connect_button.dart';
import 'panel.dart';
import 'status_badge.dart';

/// Big hero on the home screen: status badge, ↓ live speed, connect button.
class HeroStatus extends StatelessWidget {
  final TelemetrySnapshot telemetry;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const HeroStatus({
    super.key,
    required this.telemetry,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final state = telemetry.state;
    final speed = splitRate(telemetry.rxBps);
    final connected = state == VpnState.connected;

    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(state: state),
              const Spacer(),
              if (connected)
                Row(
                  children: [
                    Text(
                      'СЕССИЯ ',
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      formatBytes(
                          telemetry.sessionRxBytes + telemetry.sessionTxBytes),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text('  ·  ',
                        style: TextStyle(color: AppColors.textDim)),
                    Text(
                      formatDuration(telemetry.uptime),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8, right: 4),
                child: Text(
                  '↓',
                  style: TextStyle(
                      color: AppColors.ok,
                      fontSize: 28,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                speed.value,
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  height: 1.0,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Text(
                  speed.unit,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            connected
                ? '${telemetry.carrier ?? '—'} · ${Transport.label(telemetry.transport ?? '')} · '
                    '${formatLatency(telemetry.latencyMs)} · ↑ ${formatRate(telemetry.txBps)}'
                : 'ожидание подключения',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          ConnectButton(
            state: state,
            onPressed: connected ? onDisconnect : onConnect,
          ),
        ],
      ),
    );
  }
}
