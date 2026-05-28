import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../theme/colors.dart';

/// Tunnel state pill: ● TUNNEL ACTIVE / ◇ CONNECTING / ✕ STOPPED.
class StatusBadge extends StatelessWidget {
  final VpnState state;
  const StatusBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      VpnState.connected =>
        ('TUNNEL ACTIVE', AppColors.ok),
      VpnState.connecting =>
        ('CONNECTING', AppColors.primaryLt),
      VpnState.reconnecting =>
        ('RECONNECTING', AppColors.tagTun),
      VpnState.failed =>
        ('FAILED', AppColors.err),
      VpnState.disconnected =>
        ('STOPPED', AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}
