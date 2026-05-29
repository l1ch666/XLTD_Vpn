import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/transport.dart';
import '../theme/colors.dart';

/// Loads the v3 design-drop SVG glyphs (`assets/icons/ic_*.svg`) and tints
/// them with [color] via [ColorFilter]. The SVGs use `currentColor`, so the
/// tint fully overrides stroke/fill at render time.
///
/// Keep the asset names in sync with `_design_drop/**/assets`.
class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;

  const AppIcon(
    this.asset, {
    super.key,
    this.size = 22,
    this.color = AppColors.text,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$asset',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  // ── named helpers ─────────────────────────────────────────────────────

  /// Nav-rail / bottom-nav glyph for a tab index (0..4).
  static String navAsset(int tab) {
    switch (tab) {
      case 0:
        return 'ic_nav_home.svg';
      case 1:
        return 'ic_nav_profiles.svg';
      case 2:
        return 'ic_nav_traffic.svg';
      case 3:
        return 'ic_nav_settings.svg';
      case 4:
        return 'ic_nav_log.svg';
      default:
        return 'ic_nav_home.svg';
    }
  }

  /// Transport glyph asset for a canonical transport id.
  static String transportAsset(String transport) {
    switch (transport) {
      case Transport.sei:
        return 'ic_transport_sei.svg';
      case Transport.vp8:
        return 'ic_transport_vp8.svg';
      case Transport.video:
        return 'ic_transport_video.svg';
      case Transport.data:
      default:
        return 'ic_transport_data.svg';
    }
  }
}
