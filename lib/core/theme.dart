import 'package:flutter/material.dart';

/// SLST brand tokens carried over from the legacy web app (style.css).
///
/// The Windows and Android redesigns evolved slightly different names for the
/// same palette; both naming schemes are kept here as aliases so every screen
/// (desktop-dense tables and touch-first Material 3 surfaces alike) resolves to
/// an identical colour.
class SlstColors {
  // Brand reds.
  static const brand = Color(0xFFD93223);
  static const brandHover = Color(0xFFB92820);
  static const brandDark = Color(0xFFB92820); // alias of brandHover (Android)
  static const brandLight = Color(0xFFBF4F45);
  static const brandSoft = Color(0x14D93223); // rgba(217,50,35,0.08)

  // Light surfaces.
  static const surface = Color(0xFFFFFFFF); // white cards
  static const card = Color(0xFFFFFFFF); // alias of surface (Android)
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const surfaceSubtle = Color(0xFFF3F5F8);
  static const surfaceAlt = Color(0xFFF3F5F8); // alias of surfaceSubtle (Android)
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);

  // Dark surfaces.
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceMuted = Color(0xFF334155);
  static const darkSurfaceSubtle = Color(0xFF0F172A);
  static const darkBorder = Color(0xFF475569);
  static const darkBorderStrong = Color(0xFF64748B);

  // Text.
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const darkInk = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8);

  // Action colours (legacy web .btn-* classes).
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF059669);
  static const green = Color(0xFF059669); // alias of success (Android)
  static const info = Color(0xFF0284C7);
  static const blue = Color(0xFF0284C7); // alias of info (Android)
  static const blueBright = Color(0xFF3B82F6);
  static const notify = Color(0xFF3B82F6); // alias of blueBright
  static const purple = Color(0xFF7C3AED);
  static const slate = Color(0xFF475569);
  static const warning = Color(0xFFF59E0B);

  // Staging status row colours (light theme).
  static const statusPartial = Color(0xFFFFEDD5);
  static const statusToday = Color(0xFFFEE2E2);
  static const statusTomorrow = Color(0xFFFEF9C3);
  static const statusFuture = Color(0xFFDBEAFE);
  static const statusCorpPick = Color(0xFFDCFCE7);
  static const statusCustomerPick = Color(0xFFF3E8FF);

  // Staging status row colours (dark theme).
  static const statusPartialDark = Color(0x33F97316);
  static const statusTodayDark = Color(0x33EF4444);
  static const statusTomorrowDark = Color(0x33EAB308);
  static const statusFutureDark = Color(0x333B82F6);
  static const statusCorpPickDark = Color(0x3322C55E);
  static const statusCustomerPickDark = Color(0x33A855F7);

  // Legacy status fills used by [statusStyleFor] (Android chip/card tints).
  static const shipToday = Color(0xFFFEE2E2);
  static const shipTomorrow = Color(0xFFFEF3C7);
  static const partial = Color(0xFFFFEDD5);
  static const future = Color(0xFFDBEAFE);
  static const ready = Color(0xFFDCFCE7);
  static const pickup = Color(0xFFF3E8FF);
  static const hold = Color(0xFFE2E8F0);
}

/// Resolved colours + icon for one staging status, adapted to light/dark.
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
  final oswald = base.apply(
    fontFamily: kBodyFontFamily,
    displayColor: base.bodyLarge?.color,
    bodyColor: base.bodyLarge?.color,
  );
  return oswald.copyWith(
    displayLarge: oswald.displayLarge?.copyWith(fontWeight: FontWeight.w600),
    displayMedium: oswald.displayMedium?.copyWith(fontWeight: FontWeight.w600),
    displaySmall: oswald.displaySmall?.copyWith(fontWeight: FontWeight.w600),
    headlineLarge: oswald.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
    headlineMedium: oswald.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
    headlineSmall: oswald.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: oswald.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: oswald.titleMedium?.copyWith(fontWeight: FontWeight.w500),
  );
}

const kBrandFontFamily = 'SLSTBrand';
const kBodyFontFamily = 'Oswald';

ThemeData buildSlstTheme({required bool dark}) {
  final scheme = dark
      ? ColorScheme.fromSeed(
          seedColor: SlstColors.brand,
          brightness: Brightness.dark,
        ).copyWith(
          // Pin brand + slate tokens so seed drift doesn't wash out red or
          // float surfaces away from the Windows/Android shared shell.
          primary: SlstColors.brand,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF7F1D1D),
          onPrimaryContainer: const Color(0xFFFFDAD5),
          secondary: const Color(0xFF7DD3FC),
          onSecondary: const Color(0xFF0C4A6E),
          secondaryContainer: const Color(0xFF075985),
          onSecondaryContainer: const Color(0xFFE0F2FE),
          tertiary: const Color(0xFFC4B5FD),
          onTertiary: const Color(0xFF4C1D95),
          tertiaryContainer: const Color(0xFF5B21B6),
          onTertiaryContainer: const Color(0xFFEDE9FE),
          surface: SlstColors.darkSurfaceSubtle,
          onSurface: SlstColors.darkInk,
          onSurfaceVariant: SlstColors.darkMuted,
          surfaceContainerLowest: const Color(0xFF0B1220),
          surfaceContainerLow: SlstColors.darkSurface,
          surfaceContainer: SlstColors.darkSurface,
          surfaceContainerHigh: SlstColors.darkSurfaceMuted,
          surfaceContainerHighest: const Color(0xFF3F4F63),
          outline: SlstColors.darkBorderStrong,
          outlineVariant: SlstColors.darkBorder,
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

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: kBodyFontFamily,
  );
  final textTheme = _brandTextTheme(base.textTheme);

  // Desktop density: keep the touch-first Material 3 look on mobile while
  // giving the Windows shell tighter tables, always-visible scrollbars and
  // tooltips.
  return base.copyWith(
    textTheme: textTheme,
    // The M3 scheme surface (F8FAFC) reads as the light "muted" backdrop; use
    // it for the scaffold so cards (white) still stand out on both platforms.
    scaffoldBackgroundColor: dark ? scheme.surface : SlstColors.surfaceMuted,
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
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
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
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
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
      // Sheets close via an explicit X button in their header row; the drag
      // handle would be redundant chrome (swipe-down still works).
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: const TextStyle(
        fontFamily: kBodyFontFamily,
        color: Colors.white,
        fontSize: 12,
      ),
      decoration: BoxDecoration(
        color: dark ? SlstColors.darkSurfaceMuted : SlstColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
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
        color: dark ? SlstColors.darkMuted : SlstColors.muted,
      ),
      dataTextStyle: TextStyle(
        fontFamily: kBodyFontFamily,
        fontSize: 13.5,
        color: dark ? SlstColors.darkInk : SlstColors.ink,
      ),
      dividerThickness: 1,
      headingRowColor: WidgetStatePropertyAll(
        dark ? SlstColors.darkSurfaceMuted : SlstColors.surfaceMuted,
      ),
    ),
  );
}
