import 'package:flutter/material.dart';

/// SLST brand tokens carried over from the legacy web app (style.css).
class SlstColors {
  // Brand red.
  static const brand = Color(0xFFD93223);
  static const brandDark = Color(0xFFB92820);
  static const brandSoft = Color(0x14D93223); // rgba(217,50,35,0.08)

  // Action accents from the legacy UI.
  static const purple = Color(0xFF7C3AED); // Batch / Quick Consolidate
  static const green = Color(0xFF059669); // Quick Ship / success
  static const blue = Color(0xFF0284C7); // Changelog / notify
  static const blueBright = Color(0xFF3B82F6);

  // Surfaces & text.
  static const surface = Color(0xFFF8FAFC);
  static const surfaceAlt = Color(0xFFF3F5F8);
  static const card = Colors.white;
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);

  // Legacy status fills (used as chip/card tints in light mode).
  static const shipToday = Color(0xFFFEE2E2);
  static const shipTomorrow = Color(0xFFFEF3C7);
  static const partial = Color(0xFFFFEDD5);
  static const future = Color(0xFFDBEAFE);
  static const ready = Color(0xFFDCFCE7);
  static const pickup = Color(0xFFF3E8FF);
  static const hold = Color(0xFFE2E8F0);
}

/// Resolved colors + icon for one staging status, adapted to light/dark.
class StatusStyle {
  const StatusStyle({
    required this.label,
    required this.fill,
    required this.accent,
    required this.icon,
  });

  final String label;

  /// Soft background tint (chip fill / card wash).
  final Color fill;

  /// Strong foreground (text, icon, accent bar).
  final Color accent;

  final IconData icon;
}

StatusStyle statusStyleFor({
  required String uiLabel,
  required bool isDateStatus,
  required bool overdue,
  required Brightness brightness,
}) {
  final dark = brightness == Brightness.dark;

  StatusStyle build(String label, Color lightFill, Color accent, IconData icon) {
    if (!dark) {
      return StatusStyle(label: label, fill: lightFill, accent: accent, icon: icon);
    }
    final hsl = HSLColor.fromColor(accent);
    final darkAccent =
        hsl.withLightness((hsl.lightness + 0.28).clamp(0.0, 1.0)).toColor();
    return StatusStyle(
      label: label,
      fill: darkAccent.withValues(alpha: 0.16),
      accent: darkAccent,
      icon: icon,
    );
  }

  final lower = uiLabel.toLowerCase();
  if (overdue) {
    return build('Overdue', SlstColors.shipToday, const Color(0xFF991B1B),
        Icons.warning_amber_rounded);
  }
  if (lower == 'ship today') {
    return build('Ship Today', SlstColors.shipToday, const Color(0xFFB91C1C),
        Icons.local_shipping);
  }
  if (lower == 'ship tomorrow') {
    return build('Ship Tomorrow', SlstColors.shipTomorrow,
        const Color(0xFFA16207), Icons.wb_twilight);
  }
  if (lower == 'partial') {
    return build('Partial', SlstColors.partial, const Color(0xFFC2410C),
        Icons.donut_large);
  }
  if (isDateStatus) {
    return build(uiLabel, SlstColors.future, const Color(0xFF1D4ED8),
        Icons.event);
  }
  if (lower.contains('corp pick')) {
    return build('Corp Pick', SlstColors.ready, const Color(0xFF047857),
        Icons.store_mall_directory);
  }
  if (lower.contains('customer pick')) {
    return build('Customer Pick-Up', SlstColors.pickup,
        const Color(0xFF7E22CE), Icons.hail);
  }
  if (lower.contains('awaiting')) {
    return build('Awaiting Instructions', SlstColors.hold,
        const Color(0xFF475569), Icons.hourglass_empty);
  }
  return build(uiLabel, SlstColors.surfaceAlt, SlstColors.muted,
      Icons.inventory_2_outlined);
}

TextTheme _brandTextTheme(TextTheme base) {
  TextStyle? oswald(TextStyle? s, {FontWeight? weight}) => s?.copyWith(
        fontFamily: 'Oswald',
        fontWeight: weight ?? s.fontWeight,
        letterSpacing: 0.2,
      );
  return base.copyWith(
    displayLarge: oswald(base.displayLarge, weight: FontWeight.w600),
    displayMedium: oswald(base.displayMedium, weight: FontWeight.w600),
    displaySmall: oswald(base.displaySmall, weight: FontWeight.w600),
    headlineLarge: oswald(base.headlineLarge, weight: FontWeight.w600),
    headlineMedium: oswald(base.headlineMedium, weight: FontWeight.w600),
    headlineSmall: oswald(base.headlineSmall, weight: FontWeight.w600),
    titleLarge: oswald(base.titleLarge, weight: FontWeight.w600),
    titleMedium: oswald(base.titleMedium, weight: FontWeight.w500),
  );
}

ThemeData buildSlstTheme({required bool dark}) {
  final scheme = dark
      ? ColorScheme.fromSeed(
          seedColor: SlstColors.brand,
          brightness: Brightness.dark,
        ).copyWith(
          tertiary: const Color(0xFFC4B5FD),
          secondary: const Color(0xFF7DD3FC),
        )
      : ColorScheme.fromSeed(
          seedColor: SlstColors.brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: SlstColors.brand,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFDAD5),
          onPrimaryContainer: const Color(0xFF73150C),
          secondary: SlstColors.blue,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFDBEFFB),
          onSecondaryContainer: const Color(0xFF075985),
          tertiary: SlstColors.purple,
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFEDE9FE),
          onTertiaryContainer: const Color(0xFF5B21B6),
          surface: SlstColors.surface,
          onSurface: SlstColors.ink,
          onSurfaceVariant: SlstColors.muted,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: SlstColors.surfaceAlt,
          surfaceContainerHigh: const Color(0xFFECEFF3),
          surfaceContainerHighest: const Color(0xFFE5E9EF),
          outlineVariant: const Color(0xFFE2E8F0),
        );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final textTheme = _brandTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: scheme.surfaceTint,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 20,
        color: scheme.onSurface,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? null : Colors.white,
      indicatorColor: dark ? scheme.primaryContainer : SlstColors.brandSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.onPrimaryContainer : SlstColors.brand)
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.onSurface : SlstColors.brand)
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? null : Colors.white,
      indicatorColor: dark ? scheme.primaryContainer : SlstColors.brandSoft,
      selectedIconTheme: IconThemeData(
        color: dark ? scheme.onPrimaryContainer : SlstColors.brand,
      ),
      selectedLabelTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: dark ? scheme.onSurface : SlstColors.brand,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontSize: 12,
        color: scheme.onSurfaceVariant,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: SlstColors.brand,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHighest : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? scheme.surfaceContainerLow : Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? scheme.primaryContainer : SlstColors.brandSoft)
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? scheme.onPrimaryContainer : SlstColors.brandDark)
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
