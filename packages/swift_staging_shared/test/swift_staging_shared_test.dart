import 'package:flutter_test/flutter_test.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

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

  test('StagingEntry.fromMap parses prepared_for_shipping', () {
    final base = <String, dynamic>{
      'id': '1',
      'so': '100',
      'customer': 'Acme',
      'status': 'Staged',
      'location': 'A-01-A-1',
      'type': '1 Skid',
      'qty': 1,
    };

    // Missing key defaults to false — pre-1.1.46 rows and the insert path
    // (StagingEntry.toInsertMap omits it) must not read as "prepared".
    expect(StagingEntry.fromMap(base).preparedForShipping, isFalse);

    expect(
      StagingEntry.fromMap({...base, 'prepared_for_shipping': true})
          .preparedForShipping,
      isTrue,
    );
    expect(
      StagingEntry.fromMap({...base, 'prepared_for_shipping': false})
          .preparedForShipping,
      isFalse,
    );
    // Only a literal `true` counts — never coerce a truthy-looking string.
    expect(
      StagingEntry.fromMap({...base, 'prepared_for_shipping': 'true'})
          .preparedForShipping,
      isFalse,
    );
  });

  test('toInsertMap never sends prepared_for_shipping', () {
    // New staging rows must start unprepared via the column default, not by
    // the client asserting a value — Split/Consolidate/Ship all rely on this
    // by omission too (see their explicit insert column lists).
    final entry = StagingEntry(
      id: '1',
      so: '100',
      customer: 'Acme',
      status: 'Staged',
      location: 'A-01-A-1',
      type: '1 Skid',
      qty: 1,
      preparedForShipping: true,
    );
    expect(entry.toInsertMap().containsKey('prepared_for_shipping'), isFalse);
  });
}
