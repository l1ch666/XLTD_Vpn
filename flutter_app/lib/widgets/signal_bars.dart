import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// 4 ascending rounded bars — quality indicator on profile rows.
///
/// `_design_drop` signal_bars: width 3dp, gap 2dp, radius 2dp, height factors
/// [0.3, 0.53, 0.76, 0.99]. Filled+active = primary, filled+inactive =
/// primary_deep, empty = line.
class SignalBars extends StatelessWidget {
  /// Number of filled bars, 1..4.
  final int level;

  /// Whether this row is the active/selected one (controls filled colour).
  final bool active;

  final double height;

  const SignalBars({
    super.key,
    required this.level,
    this.active = false,
    this.height = 20,
  });

  static const _factors = [0.30, 0.53, 0.76, 0.99];

  @override
  Widget build(BuildContext context) {
    final filled = active ? AppColors.signalActive : AppColors.signalInactive;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++) ...[
            Container(
              width: 3,
              height: height * _factors[i],
              decoration: BoxDecoration(
                color: i < level ? filled : AppColors.signalEmpty,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (i < 3) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
