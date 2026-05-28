import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'panel.dart';
import 'sparkline.dart';

/// One of the four big home-screen tiles: label, value, sub-label, sparkline.
class MetricCard extends StatelessWidget {
  final String label;       // "↓ ВХОДЯЩИЙ"
  final String value;       // "1.84"
  final String unit;        // "MB/s"
  final String subLabel;    // "SEI"
  final List<double> spark; // history (0..1)
  final Color sparkColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.subLabel,
    required this.spark,
    this.sparkColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PanelLabel(label),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subLabel,
            style: TextStyle(
              fontSize: 11,
              color: sparkColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Sparkline(
            samples: spark,
            gradient: [sparkColor, sparkColor.withOpacity(0.4)],
            height: 28,
          ),
        ],
      ),
    );
  }
}
