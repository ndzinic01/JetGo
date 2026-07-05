import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF2F80ED);
  static const _background = Color(0xFFF2F7FD);
  static const _panel = Colors.white;
  static const _sidebar = Color(0xFFD6EBFF);
  static const _header = Color(0xFF33495F);

  static ThemeData get themeData {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surface: _background,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _background,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: _header,
      ),
      dividerColor: const Color(0xFFB8C8D8),
      textTheme: ThemeData.light().textTheme.copyWith(
            headlineMedium: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _header,
            ),
            headlineSmall: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _header,
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _header,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _header,
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: _panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _header,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: Colors.white,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFE7F1FF);
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStatePropertyAll(_header),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      extensions: const <ThemeExtension<dynamic>>[
        DesktopPalette(
          sidebar: _sidebar,
          header: _header,
        ),
      ],
    );
  }
}

@immutable
class DesktopPalette extends ThemeExtension<DesktopPalette> {
  const DesktopPalette({
    required this.sidebar,
    required this.header,
  });

  final Color sidebar;
  final Color header;

  @override
  DesktopPalette copyWith({
    Color? sidebar,
    Color? header,
  }) {
    return DesktopPalette(
      sidebar: sidebar ?? this.sidebar,
      header: header ?? this.header,
    );
  }

  @override
  DesktopPalette lerp(ThemeExtension<DesktopPalette>? other, double t) {
    if (other is! DesktopPalette) {
      return this;
    }

    return DesktopPalette(
      sidebar: Color.lerp(sidebar, other.sidebar, t) ?? sidebar,
      header: Color.lerp(header, other.header, t) ?? header,
    );
  }
}
