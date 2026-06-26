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

  // Neutral
  static const Color white       = Color(0xFFFFFFFF);
  static const Color background  = Color(0xFFF3F4F6);
  static const Color border      = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint    = Color(0xFF9CA3AF);
}

class BGNTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BGNColors.primary,
      primary: BGNColors.primary,
      background: BGNColors.background,
    ),
    scaffoldBackgroundColor: BGNColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: BGNColors.primary,
      foregroundColor: BGNColors.white,
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: BGNColors.white,
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
      color: BGNColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BGNColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BGNColors.white,
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