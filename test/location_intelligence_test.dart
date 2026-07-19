import 'package:flutter_test/flutter_test.dart';
import 'package:slst/domain/location_intelligence.dart';
import 'package:slst/domain/models.dart';

StagingEntry staging({
  required String id,
  required String so,
  required String location,
  String customer = 'Customer',
  String type = '1 Skid',
}) => StagingEntry(
  id: id,
  so: so,
  customer: customer,
  status: 'Partial',
  location: location,
  type: type,
  qty: 1,
);

void main() {
  test('classifies all location categories deterministically', () {
    expect(classifyLocation('A-01-A-1'), LocationCategory.aisle);
    expect(classifyLocation('A-01-A-1+2'), LocationCategory.aisle);
    expect(classifyLocation('W-2 SHIPPING'), LocationCategory.shipping);
    expect(classifyLocation('Dock staging lane'), LocationCategory.shipping);
    expect(classifyLocation('Outside west yard'), LocationCategory.outside);
    expect(classifyLocation('South Wall'), LocationCategory.floor);
    expect(classifyLocation('Ambiguous new place'), LocationCategory.floor);
  });

  test('parses aisle bins including combined suffix', () {
    final standard = parseAisleLocation('a-01-b-1');
    expect(standard?.normalized, 'A-01-B-1');
    expect(standard?.bay, 1);
    expect(parseAisleLocation('A-99-F-2')?.suffix, '2');
    expect(parseAisleLocation('A-01-A-1+2')?.suffix, '1+2');
    expect(parseAisleLocation('A-1-A-1'), isNull);
  });

  test('active staging alone determines vacancy and occupancy', () {
    final assessment = assessLocation(
      location: 'A-01-A-1',
      so: 'SO-2',
      active: [staging(id: '1', so: 'SO-1', location: 'A-01-A-1')],
      shipped: [
        ShippedEntry(
          id: 'old',
          so: 'SO-OLD',
          customer: 'Past',
          carrier: 'Carrier',
          location: 'A-01-A-1',
          type: '1 Skid',
          qty: 1,
        ),
      ],
    );
    expect(assessment.vacant, isFalse);
    expect(assessment.occupiedByDifferentOrder, isTrue);
    expect(assessment.recentHistory, hasLength(1));

    final historyOnly = assessLocation(
      location: 'B-01-A-1',
      so: 'SO-2',
      active: const [],
      shipped: [
        ShippedEntry(
          id: 'old',
          so: 'SO-OLD',
          customer: 'Past',
          carrier: 'Carrier',
          location: 'B-01-A-1',
          type: '1 Skid',
          qty: 1,
        ),
      ],
    );
    expect(historyOnly.vacant, isTrue);
  });

  test('detects same-SO consolidation and different locations', () {
    final assessment = assessLocation(
      location: 'A-01-A-1',
      so: 'SO-1',
      active: [
        staging(id: '1', so: 'SO-1', location: 'A-01-A-1'),
        staging(id: '2', so: 'SO-1', location: 'Floor 2'),
      ],
    );
    expect(assessment.hasConsolidationOpportunity, isTrue);
    expect(assessment.sameOrderElsewhere.single.id, '2');
    expect(assessment.occupiedByDifferentOrder, isFalse);
  });

  test('ignores the currently edited staging entry', () {
    final assessment = assessLocation(
      location: 'A-01-A-1',
      so: 'SO-1',
      active: [staging(id: 'editing', so: 'SO-1', location: 'A-01-A-1')],
      ignoreEntryId: 'editing',
    );
    expect(assessment.vacant, isTrue);
    expect(assessment.sameOrderElsewhere, isEmpty);
  });

  test(
    'remembered filtering removes hidden, sentinels, blanks, duplicates',
    () {
      expect(
        filterRememberedValues(
          [' Brice ', 'brice', '', 'CONSOLIDATED', 'Hidden', 'Alex'],
          hidden: ['hidden'],
        ),
        ['Alex', 'Brice'],
      );
    },
  );

  test('empty containers have no implicit skid default', () {
    const counts = ContainerCounts();
    expect(counts.total, 0);
    expect(counts.typeLabel, isEmpty);
  });
}
