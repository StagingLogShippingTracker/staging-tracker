import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swift Document Generator brand surfaces (chrome only — not status colours).
class SwiftBrandColors {
  static const accent = Color(0xFFCE4E30);
  static const accentHover = Color(0xFFB8442A);
  static const accentSoftLight = Color(0xFFF8EBE7);
  static const accentSoftDark = Color(0xFF3A221C);
  static const bgLight = Color(0xFFF4F2EF);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const panelLight = Color(0xFFF7F5F2);
  static const inkLight = Color(0xFF1A1A1A);
  static const mutedLight = Color(0xFF6B6B6B);
  static const borderLight = Color(0xFFE6E2DC);
  static const inputLight = Color(0xFFFAFAF8);
  static const elevatedLight = Color(0xFFEDE9E3);
  static const bgDark = Color(0xFF121417);
  static const surfaceDark = Color(0xFF1C1F24);
  static const panelDark = Color(0xFF16191E);
  static const inkDark = Color(0xFFF2F0EC);
  static const mutedDark = Color(0xFFA3A29C);
  static const borderDark = Color(0xFF2E333A);
  static const inputDark = Color(0xFF15181C);
  static const elevatedDark = Color(0xFF2A2E35);
}

/// Resolved light/dark chrome. Status tokens stay on [IndustrialTheme].
class IndustrialChrome extends ThemeExtension<IndustrialChrome> {
  const IndustrialChrome({
    required this.base,
    required this.surface,
    required this.header,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accentSoft,
    required this.inputFill,
  });

  final Color base;
  final Color surface;
  final Color header;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accentSoft;
  final Color inputFill;

  static IndustrialChrome of(BuildContext context) {
    return Theme.of(context).extension<IndustrialChrome>() ?? dark;
  }

  static const light = IndustrialChrome(
    base: SwiftBrandColors.bgLight,
    surface: SwiftBrandColors.surfaceLight,
    header: SwiftBrandColors.panelLight,
    border: SwiftBrandColors.borderLight,
    ink: SwiftBrandColors.inkLight,
    muted: SwiftBrandColors.mutedLight,
    accentSoft: SwiftBrandColors.accentSoftLight,
    inputFill: SwiftBrandColors.inputLight,
  );

  static const dark = IndustrialChrome(
    base: SwiftBrandColors.bgDark,
    surface: SwiftBrandColors.surfaceDark,
    header: SwiftBrandColors.panelDark,
    border: SwiftBrandColors.borderDark,
    ink: SwiftBrandColors.inkDark,
    muted: SwiftBrandColors.mutedDark,
    accentSoft: SwiftBrandColors.accentSoftDark,
    inputFill: SwiftBrandColors.inputDark,
  );

  @override
  IndustrialChrome copyWith({
    Color? base,
    Color? surface,
    Color? header,
    Color? border,
    Color? ink,
    Color? muted,
    Color? accentSoft,
    Color? inputFill,
  }) {
    return IndustrialChrome(
      base: base ?? this.base,
      surface: surface ?? this.surface,
      header: header ?? this.header,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      accentSoft: accentSoft ?? this.accentSoft,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  IndustrialChrome lerp(covariant IndustrialChrome? other, double t) {
    if (other == null) return this;
    return IndustrialChrome(
      base: Color.lerp(base, other.base, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      header: Color.lerp(header, other.header, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

/// Industrial layout + Swift chrome. Status colours are independent of theme.
class IndustrialTheme {
  static const tokens = SlstLayoutTokens();

  /// Dark-mode fallbacks for const/legacy call sites.
  static const Color darkBase = SwiftBrandColors.bgDark;
  static const Color darkSurface = SwiftBrandColors.surfaceDark;
  static const Color darkHeader = SwiftBrandColors.panelDark;
  static const Color borderStroke = SwiftBrandColors.borderDark;
  static const Color textPrimary = SwiftBrandColors.inkDark;
  static const Color textMuted = SwiftBrandColors.mutedDark;

  static IndustrialChrome chromeOf(BuildContext context) =>
      IndustrialChrome.of(context);

  // Status accent tokens (unchanged across light/dark chrome).
  static const Color mintGreen = Color(0xFF10B981); // Today / ready / live sync
  static const Color skyBlue = Color(0xFF3B82F6); // Tomorrow / transit (status)
  static const Color chromeAccent = SwiftBrandColors.accent;
  static const Color chromeAccentHover = SwiftBrandColors.accentHover;
  static const Color amber = Color(0xFFF59E0B); // Partial / awaiting
  static const Color hotRed = Color(0xFFEF4444); // Rush / Hotshot
  static const Color purple = Color(0xFF8B5CF6); // Future / special action
  static const Color slateMuted = Color(0xFF4B5563); // Delivered / occupied
  /// Awaiting Instructions in **light** mode only (darker than empty map seats).
  static const Color awaiting = Color(0xFF1F2937);

  /// Dark mode keeps the original mid-gray; light mode uses [awaiting].
  static Color awaitingOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? awaiting
        : slateMuted;
  }

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final chrome = dark ? IndustrialChrome.dark : IndustrialChrome.light;
    final base = chrome.base;
    final surface = chrome.surface;
    final header = chrome.header;
    final border = chrome.border;
    final ink = chrome.ink;
    final muted = chrome.muted;
    final elevated =
        dark ? SwiftBrandColors.elevatedDark : SwiftBrandColors.elevatedLight;

    final inter = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: ink, displayColor: ink);

    final textTheme = inter.copyWith(
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: ink,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: ink),
      bodySmall: GoogleFonts.inter(
        fontSize: 11.5,
        height: 1.25,
        color: muted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.85,
        color: muted,
      ),
    );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: chromeAccent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: chromeAccent,
          onPrimary: Colors.white,
          secondary: mintGreen,
          onSecondary: Colors.white,
          tertiary: purple,
          onTertiary: Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerLowest: base,
          surfaceContainerLow: header,
          surfaceContainer: surface,
          surfaceContainerHigh: elevated,
          surfaceContainerHighest: elevated,
          outline: border,
          outlineVariant: border,
          error: const Color(0xFFEF4444),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: base,
      primaryColor: header,
      textTheme: textTheme,
      extensions: [const SlstLayoutTokens(), chrome],
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: header,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 16),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chrome.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: chromeAccent, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: header,
        contentTextStyle: GoogleFonts.inter(color: ink, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: GoogleFonts.inter(color: ink, fontSize: 12),
        decoration: BoxDecoration(
          color: header,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thumbColor: WidgetStatePropertyAll(border),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(8),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.8,
          color: muted,
        ),
        dataTextStyle: GoogleFonts.inter(fontSize: 13, color: ink),
        dividerThickness: 1,
        headingRowColor: WidgetStatePropertyAll(header),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: header,
        indicatorColor: chrome.accentSoft,
        selectedIconTheme: const IconThemeData(color: chromeAccent),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        unselectedLabelTextStyle: TextStyle(fontSize: 12, color: muted),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: chromeAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: header,
        side: BorderSide(color: border),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    );
  }

  /// JetBrains Mono for SO numbers, UUIDs, weights, and timestamps.
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? SwiftBrandColors.inkDark,
    );
  }
}

/// Legacy colour aliases mapped onto industrial tokens so existing screens
/// keep compiling during the phased overhaul.
class SlstColors {
  // Brand / accents → industrial primary accents.
  static const brand = IndustrialTheme.chromeAccent;
  static const brandHover = IndustrialTheme.chromeAccentHover;
  static const brandDark = IndustrialTheme.chromeAccentHover;
  static const brandLight = Color(0xFFFFA45C);
  static const brandSoft = Color(0x14CE4E30);

  // Surfaces (industrial dark).
  static const surface = IndustrialTheme.darkSurface;
  static const card = IndustrialTheme.darkSurface;
  static const surfaceMuted = IndustrialTheme.darkBase;
  static const surfaceSubtle = IndustrialTheme.darkHeader;
  static const surfaceAlt = IndustrialTheme.darkHeader;
  static const border = IndustrialTheme.borderStroke;
  static const borderStrong = Color(0xFF4B5563);

  static const darkSurface = IndustrialTheme.darkSurface;
  static const darkSurfaceMuted = IndustrialTheme.darkHeader;
  static const darkSurfaceSubtle = IndustrialTheme.darkBase;
  static const darkBorder = IndustrialTheme.borderStroke;
  static const darkBorderStrong = Color(0xFF4B5563);

  // Text.
  static const ink = IndustrialTheme.textPrimary;
  static const muted = IndustrialTheme.textMuted;
  static const subtle = Color(0xFF6B7280);
  static const darkInk = IndustrialTheme.textPrimary;
  static const darkMuted = IndustrialTheme.textMuted;

  // Action colours.
  static const danger = Color(0xFFEF4444);
  static const success = IndustrialTheme.mintGreen;
  static const green = IndustrialTheme.mintGreen;
  static const info = IndustrialTheme.skyBlue;
  static const blue = IndustrialTheme.skyBlue;
  static const blueBright = IndustrialTheme.skyBlue;
  static const notify = IndustrialTheme.skyBlue;
  static const purple = IndustrialTheme.purple;
  static const slate = IndustrialTheme.slateMuted;
  static const warning = IndustrialTheme.amber;

  // Staging status row washes (dark industrial tints).
  static const statusPartial = Color(0x33F59E0B);
  static const statusToday = Color(0x3310B981);
  static const statusTomorrow = Color(0x333B82F6);
  static const statusFuture = Color(0x338B5CF6);
  static const statusCorpPick = Color(0x3310B981);
  static const statusCustomerPick = Color(0x338B5CF6);
  static const statusRushHotshot = Color(0x33EF4444);

  @Deprecated('Use statusPartial.')
  static const statusPartialDark = statusPartial;
  @Deprecated('Use statusToday.')
  static const statusTodayDark = statusToday;
  @Deprecated('Use statusTomorrow.')
  static const statusTomorrowDark = statusTomorrow;
  @Deprecated('Use statusFuture.')
  static const statusFutureDark = statusFuture;
  @Deprecated('Use statusCorpPick.')
  static const statusCorpPickDark = statusCorpPick;
  @Deprecated('Use statusCustomerPick.')
  static const statusCustomerPickDark = statusCustomerPick;

  // Legacy status fills used by [statusStyleFor].
  static const shipToday = Color(0x3310B981);
  static const shipTomorrow = Color(0x333B82F6);
  static const partial = Color(0x33F59E0B);
  static const future = Color(0x338B5CF6);
  static const ready = Color(0x3310B981);
  static const pickup = Color(0x338B5CF6);
  static const hold = Color(0x661F2937);
  static const rushHotshot = Color(0x33EF4444);
}

/// Shared layout scale for desktop and Android industrial surfaces.
class SlstLayoutTokens extends ThemeExtension<SlstLayoutTokens> {
  const SlstLayoutTokens({
    this.space1 = 4,
    this.space2 = 8,
    this.space3 = 12,
    this.space4 = 16,
    this.radiusSmall = 6,
    this.radiusMedium = 8,
    this.compactBreakpoint = 700,
    this.inspectorBreakpoint = 1024,
  });

  final double space1;
  final double space2;
  final double space3;
  final double space4;
  final double radiusSmall;
  final double radiusMedium;
  final double compactBreakpoint;
  final double inspectorBreakpoint;

  @override
  SlstLayoutTokens copyWith({
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? radiusSmall,
    double? radiusMedium,
    double? compactBreakpoint,
    double? inspectorBreakpoint,
  }) {
    return SlstLayoutTokens(
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      compactBreakpoint: compactBreakpoint ?? this.compactBreakpoint,
      inspectorBreakpoint: inspectorBreakpoint ?? this.inspectorBreakpoint,
    );
  }

  @override
  SlstLayoutTokens lerp(covariant SlstLayoutTokens? other, double t) {
    if (other == null) return this;
    return SlstLayoutTokens(
      space1: lerpDouble(space1, other.space1, t)!,
      space2: lerpDouble(space2, other.space2, t)!,
      space3: lerpDouble(space3, other.space3, t)!,
      space4: lerpDouble(space4, other.space4, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      compactBreakpoint: lerpDouble(
        compactBreakpoint,
        other.compactBreakpoint,
        t,
      )!,
      inspectorBreakpoint: lerpDouble(
        inspectorBreakpoint,
        other.inspectorBreakpoint,
        t,
      )!,
    );
  }
}

/// Resolved colours + icon for one staging status.
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
  StatusStyle build(String label, Color fill, Color accent, IconData icon) {
    return StatusStyle(label: label, fill: fill, accent: accent, icon: icon);
  }

  final lower = uiLabel.toLowerCase();
  if (overdue) {
    return build(
      'Overdue',
      const Color(0x33EF4444),
      const Color(0xFFEF4444),
      Icons.warning_amber_rounded,
    );
  }
  if (lower.contains('rush') || lower.contains('hotshot')) {
    return build(
      'Rush/Hotshot',
      SlstColors.rushHotshot,
      IndustrialTheme.hotRed,
      Icons.local_fire_department,
    );
  }
  if (lower == 'ship today') {
    return build(
      'Ship Today',
      SlstColors.shipToday,
      IndustrialTheme.mintGreen,
      Icons.local_shipping,
    );
  }
  if (lower == 'ship tomorrow') {
    return build(
      'Ship Tomorrow',
      SlstColors.shipTomorrow,
      IndustrialTheme.skyBlue,
      Icons.wb_twilight,
    );
  }
  if (lower == 'partial') {
    return build(
      'Partial',
      SlstColors.partial,
      IndustrialTheme.amber,
      Icons.donut_large,
    );
  }
  if (isDateStatus) {
    return build(
      uiLabel,
      SlstColors.future,
      IndustrialTheme.purple,
      Icons.event,
    );
  }
  if (lower.contains('corp pick')) {
    return build(
      'Corp Pick',
      SlstColors.ready,
      IndustrialTheme.mintGreen,
      Icons.store_mall_directory,
    );
  }
  if (lower.contains('customer pick')) {
    return build(
      'Customer Pick-Up',
      SlstColors.pickup,
      IndustrialTheme.purple,
      Icons.hail,
    );
  }
  if (lower.contains('awaiting')) {
    final accent = brightness == Brightness.light
        ? IndustrialTheme.awaiting
        : IndustrialTheme.slateMuted;
    return build(
      'Awaiting Instructions',
      accent.withValues(alpha: brightness == Brightness.light ? 0.40 : 0.28),
      accent,
      Icons.hourglass_empty,
    );
  }
  return build(
    uiLabel,
    brightness == Brightness.dark
        ? SwiftBrandColors.panelDark
        : SwiftBrandColors.panelLight,
    brightness == Brightness.dark
        ? SwiftBrandColors.mutedDark
        : SwiftBrandColors.mutedLight,
    Icons.inventory_2_outlined,
  );
}

/// Builds light or dark Swift chrome [ThemeData]. Status colours are unchanged.
ThemeData buildSlstTheme({required bool dark}) {
  return dark ? IndustrialTheme.darkTheme : IndustrialTheme.lightTheme;
}
