import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_log/core/email_subjects.dart';

void main() {
  test('capitalizeEmailSubject uppercases the entire subject', () {
    expect(
      capitalizeEmailSubject('SHIPPED: SO 12345 - acme industries'),
      'SHIPPED: SO 12345 - ACME INDUSTRIES',
    );
    expect(
      capitalizeEmailSubject('RETURN TO STOCK: SO 999 - beta corp'),
      'RETURN TO STOCK: SO 999 - BETA CORP',
    );
    expect(
      capitalizeEmailSubject('Return Notification: SO 1 - customer'),
      'RETURN NOTIFICATION: SO 1 - CUSTOMER',
    );
    expect(
      capitalizeEmailSubject('PO Notification: po123 (SO 456)'),
      'PO NOTIFICATION: PO123 (SO 456)',
    );
    expect(
      capitalizeEmailSubject('RETURN TO STOCK: Acme Industries SO# 1223344'),
      'RETURN TO STOCK: ACME INDUSTRIES SO# 1223344',
    );
  });
}
