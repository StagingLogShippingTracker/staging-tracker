import 'package:intl/intl.dart';

class StatusRules {
  static final _ymd = DateFormat('yyyy-MM-dd');

  /// UI dropdown options matching the legacy tracker.
  static const uiStatuses = <String>[
    'Partial',
    'Ship Today',
    'Ship Tomorrow',
    'Ship On Future Date',
    'Corp Pick',
    'Customer Pick-Up',
    'Awaiting Instructions',
  ];

  static String todayYmd() => _ymd.format(DateTime.now());

  static String tomorrowYmd() =>
      _ymd.format(DateTime.now().add(const Duration(days: 1)));

  static bool isYmd(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

  static String formatUi(String dbStatus) {
    if (isYmd(dbStatus)) {
      final today = todayYmd();
      final tomorrow = tomorrowYmd();
      if (dbStatus.compareTo(today) <= 0) return 'Ship Today';
      if (dbStatus == tomorrow) return 'Ship Tomorrow';
    }
    // Normalize legacy "Awaiting Shipping Instructions" to the UI label.
    if (isAwaitingInstructions(dbStatus)) return 'Awaiting Instructions';
    return dbStatus;
  }

  /// True for both current and legacy awaiting-instruction status labels.
  static bool isAwaitingInstructions(String dbStatus) {
    final lower = dbStatus.trim().toLowerCase();
    return lower == 'awaiting instructions' ||
        lower == 'awaiting shipping instructions' ||
        (lower.contains('awaiting') && lower.contains('instruction'));
  }

  static String toDb(String uiStatus, {String? futureDateYmd}) {
    if (uiStatus == 'Ship Today') return todayYmd();
    if (uiStatus == 'Ship Tomorrow') return tomorrowYmd();
    if (uiStatus == 'Ship On Future Date') {
      return (futureDateYmd == null || futureDateYmd.isEmpty)
          ? 'TBD'
          : futureDateYmd;
    }
    return uiStatus;
  }

  static bool isOverdue(String dbStatus) {
    if (!isYmd(dbStatus)) return false;
    return dbStatus.compareTo(todayYmd()) < 0;
  }

  static int urgencyWeight(String dbStatus) {
    final ui = formatUi(dbStatus).toLowerCase();
    if (ui == 'ship today' || isOverdue(dbStatus)) return 50;
    if (ui == 'ship tomorrow') return 40;
    if (ui == 'partial') return 30;
    if (isYmd(dbStatus)) return 20;
    if (ui.contains('corp pick')) return 10;
    return 0;
  }

  static const aislePattern = r'^[A-Z]-\d{2}-[A-F]-[12]$';
}
