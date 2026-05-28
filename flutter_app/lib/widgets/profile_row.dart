import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/transport.dart';
import '../theme/colors.dart';
import 'panel.dart';

/// One profile in the home list / profiles screen.
class ProfileRow extends StatelessWidget {
  final Profile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ProfileRow({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(profile.transport);
    final accent =
        profile.transport == Transport.sei ? AppColors.ok : AppColors.primary;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        onTap: onTap,
        selected: active,
        child: Row(
          children: [
            // active dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? accent : AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.bgAlt,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${profile.carrier} · ${Transport.label(profile.transport)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.comment.isEmpty ? profile.transport : profile.comment,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // signal bars (decorative)
            _SignalBars(active: active, color: accent),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String transport) {
    switch (transport) {
      case Transport.sei:
        return Icons.bolt_rounded;
      case Transport.vp8:
        return Icons.music_note_rounded;
      case Transport.data:
        return Icons.bubble_chart_rounded;
      case Transport.video:
        return Icons.videocam_rounded;
      default:
        return Icons.cable_rounded;
    }
  }
}

class _SignalBars extends StatelessWidget {
  final bool active;
  final Color color;
  const _SignalBars({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    final bars = [4.0, 8.0, 12.0, 16.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          Container(
            width: 3,
            height: bars[i],
            decoration: BoxDecoration(
              color: active ? color : AppColors.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < bars.length - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}
