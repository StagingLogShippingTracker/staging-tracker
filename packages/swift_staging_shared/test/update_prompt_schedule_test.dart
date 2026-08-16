import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

void main() {
  group('DenverTime', () {
    test('MST in January (UTC-7)', () {
      final utc = DateTime.utc(2026, 1, 15, 22, 0); // 15:00 Denver
      final denver = DenverTime.toDenver(utc);
      expect(denver.hour, 15);
      expect(denver.minute, 0);
      expect(DenverTime.isAtOrAfterDailyCheck(utc), isTrue);
    });

    test('MDT in July (UTC-6)', () {
      final utc = DateTime.utc(2026, 7, 15, 21, 0); // 15:00 Denver
      final denver = DenverTime.toDenver(utc);
      expect(denver.hour, 15);
      expect(DenverTime.dateKey(utc), '2026-07-15');
      expect(DenverTime.isAtOrAfterDailyCheck(utc), isTrue);
    });

    test('before 3pm Denver is not in window', () {
      final utc = DateTime.utc(2026, 7, 15, 20, 59); // 14:59 MDT
      expect(DenverTime.isAtOrAfterDailyCheck(utc), isFalse);
    });

    test('nextDailyCheckUtc jumps to tomorrow after window', () {
      final after = DateTime.utc(2026, 7, 15, 21, 30); // 15:30 MDT
      final next = DenverTime.nextDailyCheckUtc(after);
      final denverNext = DenverTime.toDenver(next);
      expect(denverNext.year, 2026);
      expect(denverNext.month, 7);
      expect(denverNext.day, 16);
      expect(denverNext.hour, 15);
      expect(denverNext.minute, 0);
    });

    test('spring-forward transition uses MDT after 2nd Sunday March', () {
      // 2026-03-08 is 2nd Sunday; DST starts 02:00 MST = 09:00 UTC
      final before = DateTime.utc(2026, 3, 8, 8, 59);
      final after = DateTime.utc(2026, 3, 8, 9, 0);
      expect(DenverTime.utcOffset(before), const Duration(hours: -7));
      expect(DenverTime.utcOffset(after), const Duration(hours: -6));
    });
  });

  group('UpdatePromptSchedule', () {
    const schedule = UpdatePromptSchedule();

    test('blocks while snoozed even after 3pm', () {
      final now = DateTime.utc(2026, 7, 15, 22, 0);
      final snooze = now.add(const Duration(days: 2));
      expect(
        schedule.shouldRunCheck(
          now: now,
          snoozeUntil: snooze,
          lastPromptDenverDate: null,
        ),
        isFalse,
      );
    });

    test('allows check after snooze at/after 3pm when not checked today', () {
      final now = DateTime.utc(2026, 7, 15, 21, 5); // 15:05 MDT
      expect(
        schedule.shouldRunCheck(
          now: now,
          snoozeUntil: now.subtract(const Duration(hours: 1)),
          lastPromptDenverDate: '2026-07-12',
        ),
        isTrue,
      );
    });

    test('does not re-check same Denver day', () {
      final now = DateTime.utc(2026, 7, 15, 22, 0);
      expect(
        schedule.shouldRunCheck(
          now: now,
          snoozeUntil: null,
          lastPromptDenverDate: '2026-07-15',
        ),
        isFalse,
      );
    });

    test('snoozeUntilFrom is 3 calendar days later at 15:00 Denver', () {
      // 2026-08-01 15:00 MDT = 21:00 UTC → snooze until 2026-08-04 15:00 MDT.
      final now = DateTime.utc(2026, 8, 1, 21, 0);
      final until = schedule.snoozeUntilFrom(now);
      final denver = DenverTime.toDenver(until);
      expect(denver.year, 2026);
      expect(denver.month, 8);
      expect(denver.day, 4);
      expect(denver.hour, 15);
      expect(denver.minute, 0);
    });
  });
}
