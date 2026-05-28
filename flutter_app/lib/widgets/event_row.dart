import 'package:flutter/material.dart';

import '../models/connection_status.dart';
import '../services/formatters.dart';
import '../theme/colors.dart';

/// One line in the events panel.
class EventRow extends StatelessWidget {
  final LogEvent event;
  const EventRow({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _tagColors(event.tag);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatHourMinute(event.ts),
            style: const TextStyle(
              color: AppColors.textDim,
              fontSize: 11,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.tag.toUpperCase(),
              style: TextStyle(
                color: fg,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.message,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _tagColors(String tag) {
    switch (tag) {
      case 'OK':
        return (
          AppColors.ok.withOpacity(0.18),
          AppColors.ok,
        );
      case 'DNS':
        return (
          AppColors.tagDns.withOpacity(0.18),
          AppColors.tagDns,
        );
      case 'TUN':
        return (
          AppColors.tagTun.withOpacity(0.18),
          AppColors.tagTun,
        );
      case 'HINT':
        return (
          AppColors.tagHint.withOpacity(0.18),
          AppColors.tagHint,
        );
      case 'ERR':
        return (
          AppColors.err.withOpacity(0.18),
          AppColors.err,
        );
      default:
        return (
          AppColors.surface2,
          AppColors.textMuted,
        );
    }
  }
}
