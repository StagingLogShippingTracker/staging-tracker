import 'package:flutter/material.dart';

/// Compact industrial dark theme for round/square Wear faces.
/// Uses system sans — intentionally not Oswald-heavy.
class WearTheme {
  static const Color base = Color(0xFF090D16);
  static const Color surface = Color(0xFF1F2937);
  static const Color header = Color(0xFF111827);
  static const Color border = Color(0xFF374151);
  static const Color text = Color(0xFFF9FAFB);
  static const Color muted = Color(0xFF9CA3AF);
  static const Color accent = Color(0xFF3B82F6);
  static const Color ok = Color(0xFF10B981);
  static const Color warn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: text,
      secondary: ok,
      onSecondary: base,
      surface: surface,
      onSurface: text,
      error: danger,
      onError: text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      canvasColor: base,
      cardColor: surface,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: header,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyMedium: TextStyle(fontSize: 12, color: text),
        bodySmall: TextStyle(fontSize: 11, color: muted),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: muted,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          foregroundColor: text,
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: header,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent),
        ),
      ),
    );
  }
}
