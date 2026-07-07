// lib/theme/colors.dart

import 'package:flutter/material.dart';

class BGNColors {
  // Primary
  static const Color primary     = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF1557B0);
  static const Color primaryLight = Color(0xFFE8F0FE);

  // Status
  static const Color success     = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning     = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFAEEDA);
  static const Color danger      = Color(0xFFDC2626);
  static const Color dangerLight = Color(0xFFFFEBEE);

  // Dark UI
  static const Color bg          = Color(0xFF0D1117);
  static const Color surface     = Color(0xFF161B22);
  static const Color surfaceAlt  = Color(0xFF1C2128);
  static const Color border      = Color(0xFF30363D);

  // Text on dark
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textPrimaryDark = Color(0xFF1C2128);
  static const Color textSecondary = Color(0xFFC9D1D9);
  static const Color textHint    = Color(0xFF8B949E);

  // Aliases
  static const Color white       = Color(0xFFFFFFFF);
  static const Color background  = bg;
}

class BGNTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BGNColors.primary,
      brightness: Brightness.dark,
      primary: BGNColors.primary,
      surface: BGNColors.surface,
    ),
    scaffoldBackgroundColor: BGNColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: BGNColors.surface,
      foregroundColor: BGNColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: BGNColors.surface,
      selectedItemColor: BGNColors.primary,
      unselectedItemColor: BGNColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BGNColors.primary,
        foregroundColor: BGNColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    cardTheme: CardThemeData(
      color: BGNColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BGNColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BGNColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BGNColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BGNColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BGNColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    ),
  );
}