import 'location_intelligence.dart';
import 'models.dart';

/// Other active staging rows for the same SO (case-insensitive).
///
/// Pass [ignoreEntryId] when shipping or editing a specific row so that row
/// is excluded from the sibling set.
List<StagingEntry> siblingStagingEntries({
  required String so,
  required Iterable<StagingEntry> active,
  String? ignoreEntryId,
}) {
  final order = orderKey(so);
  return active
      .where(
        (entry) =>
            orderKey(entry.so) == order &&
            (ignoreEntryId == null || entry.id != ignoreEntryId),
      )
      .toList();
}

/// Distinct leftover location labels from sibling staging rows, sorted.
List<String> leftoverLocations(Iterable<StagingEntry> siblings) {
  final seen = <String>{};
  final result = <String>[];
  for (final entry in siblings) {
    final location = entry.location.trim();
    if (location.isEmpty) continue;
    final key = locationKey(location);
    if (!seen.add(key)) continue;
    result.add(location);
  }
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}
