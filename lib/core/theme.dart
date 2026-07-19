import 'package:flutter/material.dart';

/// Brand palette ported from the legacy web app's style.css custom properties.
class SlstColors {
  // Brand reds
  static const brand = Color(0xFFD93223);
  static const brandHover = Color(0xFFB92820);
  static const brandLight = Color(0xFFBF4F45);
  static const brandSoft = Color(0x14D93223); // rgba(217,50,35,.08)

  // Light surfaces
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const surfaceSubtle = Color(0xFFF3F5F8);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);

  // Dark surfaces
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceMuted = Color(0xFF334155);
  static const darkSurfaceSubtle = Color(0xFF0F172A);
  static const darkBorder = Color(0xFF475569);
  static const darkBorderStrong = Color(0xFF64748B);

  // Text
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const darkInk = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8);

  // Action colors (web .btn-* classes)
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF059669);
  static const info = Color(0xFF0284C7);
  static const purple = Color(0xFF7C3AED);
  static const notify = Color(0xFF3B82F6);
  static const slate = Color(0xFF475569);
  static const warning = Color(0xFFF59E0B);

  // Staging status row colors (light theme)
  static const statusPartial = Color(0xFFFFEDD5);
  static const statusToday = Color(0xFFFEE2E2);
  static const statusTomorrow = Color(0xFFFEF9C3);
  static const statusFuture = Color(0xFFDBEAFE);
  static const statusCorpPick = Color(0xFFDCFCE7);
  static const statusCustomerPick = Color(0xFFF3E8FF);

  // Staging status row colors (dark theme)
  static const statusPartialDark = Color(0x33F97316);
  static const statusTodayDark = Color(0x33EF4444);
  static const statusTomorrowDark = Color(0x33EAB308);
  static const statusFutureDark = Color(0x333B82F6);
  static const statusCorpPickDark = Color(0x3322C55E);
  static const statusCustomerPickDark = Color(0x33A855F7);
}

const kBrandFontFamily = 'SLST Brand';
const kBodyFontFamily = 'Oswald';

ThemeData buildSlstTheme({required bool dark}) {
  final colorScheme = dark
      ? ColorScheme.fromSeed(
          seedColor: SlstColors.brand,
          brightness: Brightness.dark,
          primary: SlstColors.brandLight,
          surface: SlstColors.darkSurface,
          error: SlstColors.danger,
        )
      : ColorScheme.fromSeed(
          seedColor: SlstColors.brand,
          brightness: Brightness.light,
          primary: SlstColors.brand,
          surface: SlstColors.surface,
          error: SlstColors.danger,
        );

  final ink = dark ? SlstColors.darkInk : SlstColors.ink;
  final muted = dark ? SlstColors.darkMuted : SlstColors.muted;
  final border = dark ? SlstColors.darkBorder : SlstColors.border;
  final scaffold = dark ? SlstColors.darkSurfaceSubtle : SlstColors.surfaceSubtle;
  final card = dark ? SlstColors.darkSurface : SlstColors.surface;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: kBodyFontFamily,
    scaffoldBackgroundColor: scaffold,
  );

  final textTheme = base.textTheme.apply(
    fontFamily: kBodyFontFamily,
    bodyColor: ink,
    displayColor: ink,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: card,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kBodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      shadowColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: dark ? SlstColors.darkSurfaceMuted : SlstColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: SlstColors.brand, width: 1.6),
      ),
      hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w400),
      labelStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SlstColors.brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: kBodyFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: dark ? SlstColors.darkBorderStrong : SlstColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: kBodyFontFamily,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SlstColors.brand,
        textStyle: const TextStyle(
          fontFamily: kBodyFontFamily,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: dark ? SlstColors.darkBorderStrong : SlstColors.borderStrong, width: 1.4),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        fontFamily: kBodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: ink,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: const TextStyle(
        fontFamily: kBodyFontFamily,
        color: Colors.white,
        fontSize: 12,
      ),
      decoration: BoxDecoration(
        color: SlstColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? SlstColors.darkSurfaceMuted : SlstColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: kBodyFontFamily,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      thumbColor: WidgetStatePropertyAll(
        dark ? SlstColors.darkBorderStrong : SlstColors.borderStrong,
      ),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(8),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: TextStyle(
        fontFamily: kBodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.8,
        color: muted,
      ),
      dataTextStyle: TextStyle(
        fontFamily: kBodyFontFamily,
        fontSize: 13.5,
        color: ink,
      ),
      dividerThickness: 1,
      headingRowColor: WidgetStatePropertyAll(
        dark ? SlstColors.darkSurfaceMuted : SlstColors.surfaceMuted,
      ),
    ),
  );
}
