/// Daily update-prompt schedule for America/Denver (Mountain Time with DST).
///
/// Checks are due at 15:00 Denver local. Choosing "Later" snoozes for 3 days.
/// Eligible prompts always re-fetch GitHub `releases/latest` (no cached target).
library;

/// Preference keys for scheduled update prompts (SharedPreferences).
abstract final class UpdatePromptPrefs {
  static const snoozeUntilMs = 'app_update_prompt_snooze_until_ms';
  static const lastPromptDenverDate = 'app_update_prompt_last_denver_date';
}

/// Wall-clock helpers for America/Denver without pulling a timezone database.
class DenverTime {
  DenverTime._();

  static const checkHour = 15;
  static const checkMinute = 0;

  /// UTC offset for [utcInstant]: −6h during MDT, −7h during MST.
  static Duration utcOffset(DateTime utcInstant) {
    final utc = utcInstant.toUtc();
    return _isDaylightSaving(utc)
        ? const Duration(hours: -6)
        : const Duration(hours: -7);
  }

  /// Denver civil fields for [instant], stored as a UTC-kind [DateTime]
  /// whose Y/M/D/H/M are America/Denver wall-clock values (not a real UTC instant).
  static DateTime toDenver(DateTime instant) {
    final utc = instant.toUtc();
    final shifted = utc.add(utcOffset(utc));
    return DateTime.utc(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  /// `yyyy-MM-dd` calendar date in Denver for [instant].
  static String dateKey(DateTime instant) {
    final d = toDenver(instant);
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Whether [instant] is at or after today's 15:00 America/Denver.
  static bool isAtOrAfterDailyCheck(DateTime instant) {
    final denver = toDenver(instant);
    final minutes = denver.hour * 60 + denver.minute;
    return minutes >= checkHour * 60 + checkMinute;
  }

  /// Next 15:00 America/Denver as a real UTC [DateTime].
  ///
  /// If [instant] is already at/after today's check, returns tomorrow's check.
  static DateTime nextDailyCheckUtc(DateTime instant) {
    final denver = toDenver(instant);
    var year = denver.year;
    var month = denver.month;
    var day = denver.day;
    final minutes = denver.hour * 60 + denver.minute;
    if (minutes >= checkHour * 60 + checkMinute) {
      final next = DateTime.utc(year, month, day).add(const Duration(days: 1));
      year = next.year;
      month = next.month;
      day = next.day;
    }
    return denverWallToUtc(year, month, day, checkHour, checkMinute);
  }

  /// Converts Denver wall-clock components to a real UTC [DateTime].
  static DateTime denverWallToUtc(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) {
    // Try MST first; if that lands in DST, recompute with MDT.
    final asMst = DateTime.utc(year, month, day, hour + 7, minute, second);
    if (!_isDaylightSaving(asMst)) return asMst;
    return DateTime.utc(year, month, day, hour + 6, minute, second);
  }

  /// US DST for Mountain: 2nd Sunday March 02:00 MST → 1st Sunday Nov 02:00 MDT.
  static bool _isDaylightSaving(DateTime utc) {
    final year = utc.year;
    final springUtc = _nthSundayUtc(year, 3, 2, hourUtc: 9); // 02:00 MST = 09:00 UTC
    final fallUtc = _nthSundayUtc(year, 11, 1, hourUtc: 8); // 02:00 MDT = 08:00 UTC
    return !utc.isBefore(springUtc) && utc.isBefore(fallUtc);
  }

  static DateTime _nthSundayUtc(int year, int month, int n, {required int hourUtc}) {
    var day = DateTime.utc(year, month, 1);
    final distance = (DateTime.sunday - day.weekday) % 7;
    day = day.add(Duration(days: distance + (n - 1) * 7));
    return DateTime.utc(year, month, day.day, hourUtc);
  }
}

/// Pure decision helper for the daily update prompt.
class UpdatePromptSchedule {
  const UpdatePromptSchedule({
    this.snoozeDuration = const Duration(days: 3),
  });

  final Duration snoozeDuration;

  /// Whether a live GitHub check may run now (schedule + snooze only).
  ///
  /// A user-visible Update/Later dialog is shown only when that check finds
  /// a newer platform package — never when already up to date.
  bool shouldRunCheck({
    required DateTime now,
    required DateTime? snoozeUntil,
    required String? lastPromptDenverDate,
  }) {
    if (snoozeUntil != null && now.isBefore(snoozeUntil)) {
      return false;
    }
    if (!DenverTime.isAtOrAfterDailyCheck(now)) {
      return false;
    }
    final today = DenverTime.dateKey(now);
    if (lastPromptDenverDate == today) {
      return false;
    }
    return true;
  }

  DateTime snoozeUntilFrom(DateTime now) {
    final denver = DenverTime.toDenver(now);
    final plusThree = DateTime.utc(denver.year, denver.month, denver.day)
        .add(snoozeDuration);
    return DenverTime.denverWallToUtc(
      plusThree.year,
      plusThree.month,
      plusThree.day,
      DenverTime.checkHour,
      DenverTime.checkMinute,
    );
  }

  /// When to wake the in-app timer next (UTC).
  DateTime nextWakeUtc({
    required DateTime now,
    required DateTime? snoozeUntil,
  }) {
    final nextCheck = DenverTime.nextDailyCheckUtc(now);
    if (snoozeUntil != null && snoozeUntil.isAfter(now)) {
      // After snooze ends, wait until the next 3pm window (or prompt on resume
      // if already past 3pm that day — wake at snooze end so resume/timer can run).
      if (snoozeUntil.isAfter(nextCheck)) {
        return snoozeUntil.toUtc();
      }
      // Snooze ends before next check — wake at check time.
      return nextCheck;
    }
    if (!DenverTime.isAtOrAfterDailyCheck(now)) {
      return nextCheck;
    }
    // Already in today's window but not prompting (e.g. already prompted) —
    // schedule tomorrow's check.
    return nextCheck;
  }
}
