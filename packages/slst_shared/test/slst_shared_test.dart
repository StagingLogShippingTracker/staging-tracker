import 'package:flutter_test/flutter_test.dart';
import 'package:slst_shared/slst_shared.dart';

void main() {
  test('capitalizeEmailSubject uppercases', () {
    expect(
      capitalizeEmailSubject('shipped: so 1 - acme'),
      'SHIPPED: SO 1 - ACME',
    );
  });
}
