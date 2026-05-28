import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Tiny inline bar-chart matching the dashboard's mini sparklines.
/// Renders the last N samples as fixed-width vertical bars.
class Sparkline extends StatelessWidget {
  final List<double> samples;     // 0.0 .. 1.0 (normalised)
  final List<Color> gradient;     // [bright, dim]
  final double barWidth;
  final double height;

  const Sparkline({
    super.key,
    required this.samples,
    this.gradient = AppColors.sparklineGradient,
    this.barWidth = 6,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(samples, gradient, barWidth),
        size: Size.infinite,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> samples;
  final List<Color> grad;
  final double barW;

  _SparkPainter(this.samples, this.grad, this.barW);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final n = samples.length;
    final gap = 2.0;
    final totalW = n * (barW + gap);
    final scaleX = (size.width / totalW).clamp(0.0, 1.0);
    final adjBar = barW * scaleX;
    final adjGap = gap * scaleX;

    for (var i = 0; i < n; i++) {
      final v = samples[i].clamp(0.0, 1.0);
      final h = (size.height - 4) * v + 4;
      final x = i * (adjBar + adjGap);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: grad,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(x, size.height - h, adjBar, h));
      final rect = RRect.fromLTRBR(
        x,
        size.height - h,
        x + adjBar,
        size.height,
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.samples != samples || old.grad != grad || old.barW != barW;
}
