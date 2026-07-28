import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Industrial Command Center dark operations palette + ThemeData.
///
/// Windows overhaul default. Prefer [IndustrialTheme] tokens and helpers for
/// new UI; [SlstColors] / [buildSlstTheme] remain for existing call sites.
class IndustrialTheme {
  // Deep dark operations palette.
  static const Color darkBase = Color(0xFF090D16); // Scaffold background
  static const Color darkSurface = Color(0xFF1F2937); // Card & panel
  static const Color darkHeader = Color(0xFF111827); // Header & sidebar
  static const Color borderStroke = Color(0xFF374151); // Panel borders
  static const Color textPrimary = Color(0xFFF9FAFB); // Main readable text
  static const Color textMuted = Color(0xFF9CA3AF); // Subtitles / secondary

  // Status accent tokens.
  static const Color mintGreen = Color(0xFF10B981); // Today / ready / live sync
  static const Color skyBlue = Color(0xFF3B82F6); // Tomorrow / transit / accent
  static const Color amber = Color(0xFFF59E0B); // Partial / awaiting
  static const Color purple = Color(0xFF8B5CF6); // Future / special action
  static const Color slateMuted = Color(0xFF4B5563); // Delivered / completed

  static ThemeData get darkTheme {
    final inter = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final textTheme = inter.copyWith(
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: textPrimary),
      bodySmall: GoogleFonts.inter(
        fontSize: 11.5,
        height: 1.25,
        color: textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.85,
        color: textMuted,
      ),
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: skyBlue,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: skyBlue,
      onPrimary: textPrimary,
      secondary: mintGreen,
      onSecondary: darkBase,
      tertiary: purple,
      onTertiary: textPrimary,
      surface: darkSurface,
      onSurface: textPrimary,
      onSurfaceVariant: textMuted,
      surfaceContainerLowest: darkBase,
      surfaceContainerLow: darkHeader,
      surfaceContainer: darkSurface,
      surfaceContainerHigh: const Color(0xFF273549),
      surfaceContainerHighest: borderStroke,
      outline: borderStroke,
      outlineVariant: borderStroke,
      error: const Color(0xFFEF4444),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBase,
      primaryColor: darkHeader,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: darkHeader,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 16),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: borderStroke, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkHeader,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: borderStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: skyBlue, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderStroke,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: borderStroke),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkHeader,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: GoogleFonts.inter(color: textPrimary, fontSize: 12),
        decoration: BoxDecoration(
          color: darkHeader,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderStroke),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thumbColor: WidgetStatePropertyAll(borderStroke),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(8),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.8,
          color: textMuted,
        ),
        dataTextStyle: GoogleFonts.inter(fontSize: 13, color: textPrimary),
        dividerThickness: 1,
        headingRowColor: const WidgetStatePropertyAll(darkHeader),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: darkHeader,
        indicatorColor: Color(0x333B82F6),
        selectedIconTheme: IconThemeData(color: skyBlue),
        unselectedIconTheme: IconThemeData(color: textMuted),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        unselectedLabelTextStyle: TextStyle(fontSize: 12, color: textMuted),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: skyBlue,
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkHeader,
        side: const BorderSide(color: borderStroke),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textPrimary),
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
    Color color = textPrimary,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// Legacy colour aliases mapped onto industrial tokens so existing screens
/// keep compiling during the phased overhaul.
class SlstColors {
  // Brand / accents → industrial primary accents.
  static const brand = IndustrialTheme.skyBlue;
  static const brandHover = Color(0xFF2563EB);
  static const brandDark = Color(0xFF2563EB);
  static const brandLight = Color(0xFF60A5FA);
  static const brandSoft = Color(0x143B82F6);

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

  static const statusPartialDark = Color(0x33F59E0B);
  static const statusTodayDark = Color(0x3310B981);
  static const statusTomorrowDark = Color(0x333B82F6);
  static const statusFutureDark = Color(0x338B5CF6);
  static const statusCorpPickDark = Color(0x3310B981);
  static const statusCustomerPickDark = Color(0x338B5CF6);

  // Legacy status fills used by [statusStyleFor].
  static const shipToday = Color(0x3310B981);
  static const shipTomorrow = Color(0x333B82F6);
  static const partial = Color(0x33F59E0B);
  static const future = Color(0x338B5CF6);
  static const ready = Color(0x3310B981);
  static const pickup = Color(0x338B5CF6);
  static const hold = Color(0x334B5563);
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
    return build(
      'Awaiting Instructions',
      const Color(0x338B5CF6),
      IndustrialTheme.purple,
      Icons.hourglass_empty,
    );
  }
  return build(
    uiLabel,
    IndustrialTheme.darkHeader,
    IndustrialTheme.textMuted,
    Icons.inventory_2_outlined,
  );
}

/// Builds the app [ThemeData]. Always returns the industrial dark theme;
/// [dark] is retained for call-site compatibility.
ThemeData buildSlstTheme({required bool dark}) {
  return IndustrialTheme.darkTheme;
}
