import 'package:flutter/material.dart';
import 'colors.dart';

/// v3 typography families (bundled in pubspec.yaml, mirroring reference.html).
const String kFontSans  = 'IBM Plex Sans';  // content, titles, buttons, nav
const String kFontMono  = 'IBM Plex Mono';  // every number, label, timestamp, tag
const String kFontSerif = 'IBM Plex Serif'; // big dashboard page heading

/// Returns the XLTD VPN v3 dark theme (graphite + electric-blue + lime).
ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.ok,
      onSecondary: AppColors.bg,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.err,
      onError: AppColors.text,
    ),
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
          fontFamily: kFontSans,
        )
        .copyWith(
          // Hero byte counter — 44sp MONO (token: hero_counter)
          displayLarge: const TextStyle(
            fontFamily: kFontMono,
            fontSize: 44,
            fontWeight: FontWeight.w400,
            color: AppColors.text,
            height: 1.0,
            letterSpacing: -0.5,
          ),
          // Windows dashboard page heading — SERIF (token: page_title_v3)
          displayMedium: const TextStyle(
            fontFamily: kFontSerif,
            fontSize: 30,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.05,
          ),
          // Tab title — 24sp sans bold (token: tab_title)
          headlineSmall: const TextStyle(
            fontFamily: kFontSans,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
          // Status label — 16sp sans semibold (token: status)
          titleMedium: const TextStyle(
            fontFamily: kFontSans,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          // Button label — 15sp sans bold (token: button)
          labelLarge: const TextStyle(
            fontFamily: kFontSans,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          // Section title — 10sp MONO bold uppercase (token: section_title)
          labelMedium: const TextStyle(
            fontFamily: kFontMono,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textFaint,
            letterSpacing: 0.8,
          ),
          // Badge / small label — 11sp sans (token: badge)
          labelSmall: const TextStyle(
            fontFamily: kFontSans,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textLabel,
            letterSpacing: 0.4,
          ),
          // Body — 13sp sans (token: body)
          bodyMedium: const TextStyle(
            fontFamily: kFontSans,
            fontSize: 13,
            color: AppColors.textTertiary,
            height: 1.3,
          ),
          // Sub-labels — 12sp sans muted
          bodySmall: const TextStyle(
            fontFamily: kFontSans,
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.3,
          ),
        ),
    iconTheme: const IconThemeData(color: AppColors.text, size: 20),
    dividerColor: AppColors.border,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceInput,
      hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 13),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLt,
        textStyle: const TextStyle(
          fontFamily: kFontSans,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    visualDensity: VisualDensity.compact,
  );
}
