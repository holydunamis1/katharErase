import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color resizeTint = Color(0xFF2563EB);
  static const Color passportTint = Color(0xFF059669);
  static const Color watermarkTint = Color(0xFFD97706);
  static const Color exifTint = Color(0xFF7C3AED);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(seedColor: resizeTint, brightness: Brightness.light, surface: surfaceLight),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: primaryDark,
        elevation: 0,
        titleTextStyle: TextStyle(color: primaryDark, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      ),
    );
  }
}
