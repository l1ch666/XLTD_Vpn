import 'package:flutter/material.dart';

import '../models/transport.dart';
import '../theme/colors.dart';

/// SEI / VP8 / Data / Video selector chip.
class TransportChip extends StatelessWidget {
  final String transport;
  final bool active;
  final VoidCallback onTap;

  const TransportChip({
    super.key,
    required this.transport,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = transport == Transport.sei
        ? AppColors.ok
        : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent.withOpacity(0.10) : AppColors.surface,
          border: Border.all(
            color: active ? accent : AppColors.border,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? accent : AppColors.textDim,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Transport.label(transport),
              style: TextStyle(
                color: active ? AppColors.text : AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of all four transport chips. The active one comes from telemetry.
class TransportChipsRow extends StatelessWidget {
  final String? activeTransport;
  final ValueChanged<String> onSelect;
  final EdgeInsets padding;

  const TransportChipsRow({
    super.key,
    required this.activeTransport,
    required this.onSelect,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in Transport.all)
            TransportChip(
              transport: t,
              active: t == activeTransport,
              onTap: () => onSelect(t),
            ),
        ],
      ),
    );
  }
}
