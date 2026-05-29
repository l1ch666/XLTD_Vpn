import 'package:flutter/material.dart';

/// XLTD VPN v3 palette — graphite + electric-blue + lime.
///
/// Values are taken verbatim from the approved design drop
/// (`_design_drop/**/design-tokens.json`, palette_version "v3"). Each comment
/// notes the token name it maps to so the two stay in sync.
class AppColors {
  AppColors._();

  // ── Background / surface ────────────────────────────────────────────────
  static const Color bg          = Color(0xFF0E1014); // token: bg
  static const Color navBg       = Color(0xFF10131A); // bottom-nav / nav-rail bg
  static const Color bgAlt       = Color(0xFF10131A); // token: surface_input
  static const Color surface     = Color(0xFF181B22); // token: surface
  static const Color surfaceAlt  = Color(0xFF1A1D24); // token: surface_alt
  static const Color surfaceInput= Color(0xFF10131A); // token: surface_input
  static const Color surface2    = Color(0xFF1A1D24); // legacy alias → surface_alt
  static const Color border      = Color(0xFF262A33); // token: line
  static const Color line        = Color(0xFF262A33); // token: line
  static const Color lineStrong  = Color(0xFF2A3548); // token: line_strong
  static const Color borderDim   = Color(0xFF3A3F49); // token: border / border_dim

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color text          = Color(0xFFF0F1F4); // token: text / ink
  static const Color textBright     = Color(0xFFE5E7EC); // token: text_bright
  static const Color textTertiary   = Color(0xFFC8CCD4); // token: text_tertiary
  static const Color textSecondary  = Color(0xFFC2C6CE); // token: text_secondary
  static const Color textMuted      = Color(0xFF7C8089); // token: text_label / meta
  static const Color textLabel      = Color(0xFF7C8089); // token: text_label
  static const Color textDim        = Color(0xFF646A75); // token: text_dim
  static const Color textFaint      = Color(0xFF525763); // token: text_muted (faintest)

  // ── Brand ────────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF2D7DFF); // token: primary (electric blue)
  static const Color primaryLt   = Color(0xFF7DA8FF); // token: primary_light
  static const Color primaryDk   = Color(0xFF1A5FE0); // token: primary_deep / press
  static const Color primaryPale = Color(0xFFC5D9FF); // token: primary_pale
  static const Color primaryHover= Color(0xFF4F8BFF); // token: primary_hover
  static const Color accent      = Color(0xFF4F8BFF); // legacy alias → primary_hover

  // ── Semantic ───────────────────────────────────────────────────────────
  static const Color ok          = Color(0xFFC9FF3D); // token: signal/lime
  static const Color okDk        = Color(0xFF8FCC00); // darker lime (sparkline end)
  static const Color warn        = Color(0xFFE17055); // token: vp8 / WARN
  static const Color vp8         = Color(0xFFE17055); // token: vp8 accent
  static const Color video       = Color(0xFF5B8CFF); // token: video accent
  static const Color err         = Color(0xFFFF4444); // hard error red

  // ── Event-log tag colors (design-tokens.json#event_tags) ──────────────
  static const Color tagOk       = ok;        // OK   = lime
  static const Color tagDns      = primary;   // DNS  = blue
  static const Color tagLog      = textDim;   // LOG  = dim
  static const Color tagTun      = textDim;   // TUN  = dim
  static const Color tagHint     = warn;      // HINT = terracotta

  // ── Connect button gradient: blue → lime, LEFT_RIGHT ─────────────────────
  static const List<Color> connectGradient = [primary, ok];

  // ── Metric sparkline gradient: lime → blue ──────────────────────────────
  static const List<Color> sparklineGradient = [ok, primary];

  // ── Signal bars (design-tokens.json#signal_bars) ─────────────────────────
  static const Color signalActive   = primary;   // filled + active
  static const Color signalInactive = primaryDk;  // filled but not active
  static const Color signalEmpty     = line;       // unfilled

  /// Per-transport accent colour. Keys match `Transport.*` string constants.
  static Color transportAccent(String transport) {
    switch (transport) {
      case 'seichannel':
      case 'sei':
        return ok;
      case 'vp8channel':
      case 'vp8':
        return vp8;
      case 'videochannel':
      case 'video':
        return video;
      case 'datachannel':
      case 'data':
      default:
        return primary;
    }
  }
}
