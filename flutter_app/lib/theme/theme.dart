import 'package:flutter/material.dart';
import 'colors.dart';

/// Returns the XLTD VPN v3 dark theme.
ThemeData buildAppTheme() {
  const fontFamily = 'Inter'; // falls back to system default if not bundled

  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.text,
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
          fontFamily: fontFamily,
        )
        .copyWith(
          // Hero number (46sp / 46px)
          displayLarge: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            height: 1.0,
            letterSpacing: -0.5,
          ),
          // Section headings
          headlineSmall: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          // Card labels (e.g. "↓ ВХОДЯЩИЙ")
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
          // Default body
          bodyMedium: const TextStyle(
            fontSize: 13,
            color: AppColors.text,
            height: 1.4,
          ),
          // Sub-labels
          bodySmall: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.3,
          ),
        ),
    iconTheme: const IconThemeData(color: AppColors.text, size: 20),
    dividerColor: AppColors.border,
    cardTheme: CardTheme(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLt,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
    visualDensity: VisualDensity.compact,
  );
}
