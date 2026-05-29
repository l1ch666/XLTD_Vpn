import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../services/formatters.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// Centred Android hero: status-badge pill, big mono session-bytes counter,
/// and a sub-caption. Matches `_design_drop/drop1/android` `buildHero`.
/// The connect button is rendered separately, below the hero.
class HeroStatus extends StatelessWidget {
  final TelemetrySnapshot telemetry;

  const HeroStatus({super.key, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final state = telemetry.state;
    final connected = state == VpnState.connected;
    final session = formatBytes(
      telemetry.sessionRxBytes + telemetry.sessionTxBytes,
    );
    final parts = session.split(' ');
    final counterValue = parts.isNotEmpty ? parts[0] : '0';
    final counterUnit = parts.length > 1 ? parts[1] : 'B';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Badge(state: state, carrier: telemetry.carrier),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              counterValue,
              style: const TextStyle(
                fontFamily: kFontMono,
                fontSize: 44,
                color: Colors.white,
                height: 1.0,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              counterUnit,
              style: const TextStyle(
                fontFamily: kFontMono,
                fontSize: 16,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          connected ? 'передано за сессию' : 'ожидание подключения',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textFaint,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final VpnState state;
  final String? carrier;
  const _Badge({required this.state, required this.carrier});

  @override
  Widget build(BuildContext context) {
    final (label, dot) = switch (state) {
      VpnState.connected => (
          'Подключено · ${_carrierLabel(carrier)}',
          AppColors.ok,
        ),
      VpnState.connecting => ('Подключение…', AppColors.primary),
      VpnState.reconnecting => ('Переподключение…', AppColors.primary),
      VpnState.failed => ('Ошибка подключения', AppColors.warn),
      VpnState.disconnected => ('Готов к подключению', AppColors.borderDim),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow: dot == AppColors.borderDim
                  ? null
                  : [BoxShadow(color: dot.withOpacity(0.6), blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLabel,
            ),
          ),
        ],
      ),
    );
  }

  String _carrierLabel(String? c) {
    if (c == null || c.isEmpty) return 'olcRTC';
    return c;
  }
}
