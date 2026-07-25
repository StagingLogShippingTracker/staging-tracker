import 'models.dart';

/// Warehouse-walk ordering used by Staging Verification Report.
List<Comparable> locKey(String? location) {
  final l = (location ?? '').toUpperCase();
  if (l.contains('PARTIAL BOX SHELF')) return [2, l];
  if (l.contains('BOX SHELF') && !l.contains('SHIPPING')) return [1, l];
  final aisle = RegExp(r'^([A-Z])-(\d{2})-([A-Z])-(1|2|1\+2)$').firstMatch(l);
  if (aisle != null) {
    final suffix = aisle.group(4) == '1' ? 1 : (aisle.group(4) == '2' ? 2 : 3);
    return [3, aisle.group(1)!, int.parse(aisle.group(2)!), aisle.group(3)!, suffix];
  }
  if (l.contains('SOUTH WALL')) return [4, l];
  if (RegExp(r'^W-\d+').hasMatch(l) || l.contains('SHIPPING')) return [5, l];
  if (l.contains('CORP DROP')) return [6, l];
  return [7, l];
}

int compareAuditLocations(StagingEntry a, StagingEntry b) {
  final ka = locKey(a.location), kb = locKey(b.location);
  for (var i = 0; i < ka.length && i < kb.length; i++) {
    final c = ka[i].compareTo(kb[i]);
    if (c != 0) return c;
  }
  return ka.length.compareTo(kb.length);
}

enum AuditMode { all, aisle, nonAisle, discrepancies }

String auditModeName(AuditMode m) => switch (m) {
      AuditMode.all => 'all',
      AuditMode.aisle => 'aisle',
      AuditMode.nonAisle => 'non_aisle',
      AuditMode.discrepancies => 'discrepancies',
    };

AuditMode auditModeFromName(String s) => switch (s) {
      'aisle' => AuditMode.aisle,
      'non_aisle' => AuditMode.nonAisle,
      'discrepancies' => AuditMode.discrepancies,
      _ => AuditMode.all,
    };
