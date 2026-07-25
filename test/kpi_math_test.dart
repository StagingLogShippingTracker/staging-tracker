
import 'package:flutter_test/flutter_test.dart';
import 'package:slst/data/app_state.dart';
import 'package:slst/domain/models.dart';

void main() {
  test('orderCount is staging-only unique SOs', () {
    final data = AppData(
      staging: [
        StagingEntry(id: '1', so: 'SO-1', customer: 'A', status: 'Partial', location: 'A-01-A-1', type: '1 Skid', qty: 1, entryDate: DateTime(2026, 1, 1)),
        StagingEntry(id: '2', so: 'SO-1', customer: 'A', status: 'Partial', location: 'A-01-A-2', type: '1 Box', qty: 1, entryDate: DateTime(2026, 1, 1)),
        StagingEntry(id: '3', so: 'SO-2', customer: 'B', status: 'Partial', location: 'A-01-B-1', type: '1 Skid', qty: 1, entryDate: DateTime(2026, 1, 1)),
      ],
      shipped: [
        ShippedEntry(id: '9', so: 'SO-9', customer: 'C', carrier: 'X', location: 'Z', type: '1 Skid', qty: 1, shippedAt: DateTime(2026, 1, 2)),
      ],
    );
    expect(data.orderCount, 2);
  });

  test('shippedCount excludes returns and consolidate markers', () {
    final data = AppData(
      shipped: [
        ShippedEntry(id: '1', so: 'SO-1', customer: 'A', carrier: 'Day & Ross', location: 'Z', type: '1 Skid', qty: 1, shippedAt: DateTime(2026, 1, 2)),
        ShippedEntry(id: '2', so: 'SO-2', customer: 'A', carrier: 'RETURNED TO STOCK', location: 'Z', type: '1 Skid', qty: 1, shippedAt: DateTime(2026, 1, 2)),
        ShippedEntry(id: '3', so: 'SO-3', customer: 'A', carrier: 'CONSOLIDATED', location: 'Z', type: '1 Skid', qty: 1, shippedAt: DateTime(2026, 1, 2)),
      ],
    );
    expect(data.shippedCount, 1);
    expect(data.containerTotals['shipped'], 1);
  });
}
