import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_log/core/popup_gate.dart';

void main() {
  test('exclusive blocks re-entrant opens of the same key', () async {
    var opens = 0;
    Future<String?> show() async {
      opens++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return 'ok';
    }

    final first = PopupGate.exclusive('k', show);
    final second = PopupGate.exclusive('k', show);
    expect(await second, isNull);
    expect(await first, 'ok');
    expect(opens, 1);

    expect(await PopupGate.exclusive('k', show), 'ok');
    expect(opens, 2);
  });

  test('exclusive allows different keys at the same time', () async {
    var aOpen = false;
    var bOpen = false;

    final a = PopupGate.exclusive('a', () async {
      aOpen = true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      aOpen = false;
      return 1;
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = PopupGate.exclusive('b', () async {
      expect(aOpen, isTrue);
      bOpen = true;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bOpen = false;
      return 2;
    });

    expect(await Future.wait([a, b]), [1, 2]);
    expect(aOpen || bOpen, isFalse);
  });
}
