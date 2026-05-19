import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF0F766E);

  static ThemeData get themeData {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF7FAFC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7FAFC),
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
