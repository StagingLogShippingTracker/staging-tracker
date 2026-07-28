import 'package:flutter_test/flutter_test.dart';
import 'package:slst_shared/slst_shared.dart';

void main() {
  test('capitalizeEmailSubject uppercases', () {
    expect(
      capitalizeEmailSubject('shipped: so 1 - acme'),
      'SHIPPED: SO 1 - ACME',
    );
  });

  test('ship timestamp and audit ordering use shared conventions', () {
    expect(
      formatShipNotificationTimestamp(DateTime(2026, 7, 28, 13, 5, 9)),
      '7/28/2026, 1:05:09 PM',
    );

    final aisle = StagingEntry(
      id: 'aisle',
      so: '100',
      customer: 'Acme',
      status: 'Staged',
      location: 'A-01-A-1',
      type: '1 Skid',
      qty: 1,
    );
    final shelf = StagingEntry(
      id: 'shelf',
      so: '101',
      customer: 'Acme',
      status: 'Staged',
      location: 'BOX SHELF',
      type: '1 Box',
      qty: 1,
    );

    expect(compareAuditLocations(shelf, aisle), lessThan(0));
  });
}
