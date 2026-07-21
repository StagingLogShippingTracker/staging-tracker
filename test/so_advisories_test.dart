import 'package:flutter_test/flutter_test.dart';
import 'package:slst/domain/models.dart';
import 'package:slst/domain/so_advisories.dart';

StagingEntry staging({
  required String id,
  required String so,
  required String location,
}) => StagingEntry(
  id: id,
  so: so,
  customer: 'Customer',
  status: 'Partial',
  location: location,
  type: '1 Skid',
  qty: 1,
);

void main() {
  test('siblingStagingEntries finds same SO ignoring case and self', () {
    final active = [
      staging(id: 'a', so: 'SO-100', location: 'A-01-A-1'),
      staging(id: 'b', so: 'so-100', location: 'Floor 2'),
      staging(id: 'c', so: 'SO-200', location: 'Dock'),
    ];

    final siblings = siblingStagingEntries(
      so: 'SO-100',
      active: active,
      ignoreEntryId: 'a',
    );

    expect(siblings.map((e) => e.id), ['b']);
  });

  test('siblingStagingEntries empty when SO is alone', () {
    final siblings = siblingStagingEntries(
      so: 'SO-1',
      active: [staging(id: 'only', so: 'SO-1', location: 'A-01-A-1')],
      ignoreEntryId: 'only',
    );
    expect(siblings, isEmpty);
  });

  test('leftoverLocations dedupes and sorts, skips blanks', () {
    final locations = leftoverLocations([
      staging(id: '1', so: 'SO-1', location: ' Floor 2 '),
      staging(id: '2', so: 'SO-1', location: 'A-01-A-1'),
      staging(id: '3', so: 'SO-1', location: 'floor 2'),
      staging(id: '4', so: 'SO-1', location: '  '),
    ]);
    expect(locations, ['A-01-A-1', 'Floor 2']);
  });
}
