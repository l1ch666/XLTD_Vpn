import 'package:flutter/material.dart';

/// XLTD VPN v3 palette — graphite + electric-blue + lime.
///
/// Mirrors the constants in MainActivity.java (Android) and
/// renderer/style.css `:root` (Windows Electron, pre-Flutter).
class AppColors {
  AppColors._();

  // Background / surface
  static const Color bg          = Color(0xFF0E1014);
  static const Color bgAlt       = Color(0xFF0C0E12);
  static const Color surface     = Color(0xFF181B22);
  static const Color surface2    = Color(0xFF1A2038);
  static const Color border      = Color(0xFF262A33);

  // Text
  static const Color text        = Color(0xFFF0F1F4);
  static const Color textMuted   = Color(0xFF7C8089);
  static const Color textDim     = Color(0xFF66667A);

  // Brand
  static const Color primary     = Color(0xFF2D7DFF); // electric blue
  static const Color primaryLt   = Color(0xFF7DA8FF);
  static const Color primaryDk   = Color(0xFF1A5FE0);
  static const Color primaryPale = Color(0xFFD7EAFF);
  static const Color accent      = Color(0xFF4F8BFF);

  // Semantic
  static const Color ok          = Color(0xFFC9FF3D); // lime (SEI / connected)
  static const Color okDk        = Color(0xFF8FCC00);
  static const Color warn        = Color(0xFFE17055);
  static const Color err         = Color(0xFFFF4444);

  // Tag colors for event log (mirrors xltd design.html)
  static const Color tagOk       = ok;
  static const Color tagDns      = Color(0xFF7DA8FF);
  static const Color tagLog      = textMuted;
  static const Color tagTun      = Color(0xFFFFB85C);
  static const Color tagHint     = Color(0xFFE17055);

  // Connect button gradient
  static const List<Color> connectGradient = [
    Color(0xFF4F8BFF),
    Color(0xFF1A5FE0),
  ];

  // Sparkline gradient (lime)
  static const List<Color> sparklineGradient = [
    ok,
    okDk,
  ];
}
