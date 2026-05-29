import 'package:flutter/material.dart';

import '../models/transport.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// SEI / VP8 / Data / Video selector chip.
///
/// Matches `_design_drop` chip spec — inactive: surface bg, 1dp line border,
/// border_dim dot, dim mono label. Active: #0F1A33 bg, 1dp primary border,
/// primary_pale label, dot = per-transport accent (SEI lime / VP8 terracotta /
/// Video & Data blue).
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
    final accent = AppColors.transportAccent(transport);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0F1A33) : AppColors.surface,
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
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
                color: active ? accent : AppColors.borderDim,
                shape: BoxShape.circle,
                boxShadow: active && transport == Transport.sei
                    ? [BoxShadow(color: accent, blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              Transport.label(transport),
              style: TextStyle(
                fontFamily: kFontMono,
                color: active ? AppColors.primaryPale : AppColors.textDim,
                fontWeight: FontWeight.w500,
                fontSize: 11,
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
  final MainAxisAlignment alignment;

  const TransportChipsRow({
    super.key,
    required this.activeTransport,
    required this.onSelect,
    this.padding = EdgeInsets.zero,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: alignment == MainAxisAlignment.center
            ? WrapAlignment.center
            : WrapAlignment.start,
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
