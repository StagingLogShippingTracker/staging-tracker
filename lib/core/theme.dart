import 'package:flutter/material.dart';

class SlstColors {
  static const brand = Color(0xFFD93223);
  static const brandDark = Color(0xFFB0281C);
  static const surface = Color(0xFFF7F7F8);
  static const card = Colors.white;
  static const ink = Color(0xFF1F2933);
  static const muted = Color(0xFF6B7280);
  static const shipToday = Color(0xFFFEE2E2);
  static const shipTomorrow = Color(0xFFFEF3C7);
  static const ready = Color(0xFFDCFCE7);
  static const hold = Color(0xFFE0E7FF);
}

ThemeData buildSlstTheme({required bool dark}) {
  final seed = SlstColors.brand;
  final base = dark
      ? ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        )
      : ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
            surface: SlstColors.surface,
          ),
          useMaterial3: true,
        );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: seed,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: SlstColors.brand,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    ),
  );
}
