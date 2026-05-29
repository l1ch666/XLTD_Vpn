import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';
import 'sparkline.dart';

/// One of the home/traffic metric tiles: mono label, big mono value, delta,
/// and (Windows only) an 8-bar sparkline.
///
/// Android (`showSpark == false`): label 10sp mono muted, value 18sp mono,
/// delta 10sp mono primary, radius 12, padding 10/12 — no sparkline.
/// Windows (`showSpark == true`): value 23sp mono, delta primary_light,
/// sparkline gradient primary → primary_deep, radius 14, padding 13/15.
class MetricCard extends StatelessWidget {
  final String label; // "↓ ВХОДЯЩИЙ"
  final String value; // "1.84"
  final String unit; // "MB/s"
  final String subLabel; // delta — "SEI · 12 lanes"
  final List<double> spark; // history (0..1)
  final bool showSpark;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.subLabel,
    this.spark = const [],
    this.showSpark = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueSize = showSpark ? 23.0 : 18.0;
    final deltaColor = showSpark ? AppColors.primaryLt : AppColors.primary;
    final radius = showSpark ? 14.0 : 12.0;
    final pad = showSpark
        ? const EdgeInsets.fromLTRB(15, 13, 15, 13)
        : const EdgeInsets.fromLTRB(12, 10, 12, 10);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kFontMono,
              fontSize: 10,
              color: AppColors.textFaint,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: valueSize,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 11,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kFontMono,
              fontSize: 10,
              color: deltaColor,
            ),
          ),
          if (showSpark) ...[
            const SizedBox(height: 9),
            Sparkline(
              samples: spark.isEmpty ? const [0.2, 0.4, 0.3, 0.6, 0.5, 0.8, 0.7, 1.0] : spark,
              gradient: const [AppColors.primary, AppColors.primaryDk],
              height: 22,
            ),
          ],
        ],
      ),
    );
  }
}
