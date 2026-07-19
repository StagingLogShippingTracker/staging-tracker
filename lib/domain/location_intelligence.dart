import 'models.dart';

enum LocationCategory {
  aisle('Aisle Location', 'location_aisle'),
  floor('Floor Locations', 'location_floor'),
  shipping('Stage for Shipping', 'location_shipping'),
  outside('Outside', 'location_outside');

  const LocationCategory(this.label, this.rosterType);
  final String label;
  final String rosterType;
}

final aisleLocationPattern = RegExp(
  r'^([A-Z])-(\d{2})-([A-Z])-(1|2|1\+2)$',
  caseSensitive: false,
);

class AisleLocation {
  const AisleLocation({
    required this.aisle,
    required this.bay,
    required this.level,
    required this.suffix,
  });

  final String aisle;
  final int bay;
  final String level;
  final String suffix;

  String get normalized =>
      '$aisle-${bay.toString().padLeft(2, '0')}-$level-$suffix';
}

AisleLocation? parseAisleLocation(String raw) {
  final match = aisleLocationPattern.firstMatch(raw.trim().toUpperCase());
  if (match == null) return null;
  return AisleLocation(
    aisle: match.group(1)!,
    bay: int.parse(match.group(2)!),
    level: match.group(3)!,
    suffix: match.group(4)!,
  );
}

LocationCategory classifyLocation(String raw) {
  final value = raw.trim().toUpperCase();
  if (parseAisleLocation(value) != null) return LocationCategory.aisle;
  if (RegExp(r'\b(OUTSIDE|YARD|EXTERIOR)\b').hasMatch(value)) {
    return LocationCategory.outside;
  }
  if (RegExp(r'\b(SHIPPING|SHIP|STAGE|STAGING LANE|DOCK)\b').hasMatch(value) ||
      RegExp(r'^W-\d+').hasMatch(value)) {
    return LocationCategory.shipping;
  }
  return LocationCategory.floor;
}

String locationKey(String value) => value.trim().toUpperCase();
String orderKey(String value) => value.trim().toUpperCase();

class LocationAssessment {
  const LocationAssessment({
    required this.location,
    required this.sameOrder,
    required this.occupants,
    required this.sameOrderElsewhere,
    required this.recentHistory,
  });

  final String location;
  final String sameOrder;
  final List<StagingEntry> occupants;
  final List<StagingEntry> sameOrderElsewhere;
  final List<ShippedEntry> recentHistory;

  bool get vacant => occupants.isEmpty;
  bool get occupiedByDifferentOrder =>
      occupants.any((entry) => orderKey(entry.so) != orderKey(sameOrder));
  bool get hasConsolidationOpportunity =>
      occupants.any((entry) => orderKey(entry.so) == orderKey(sameOrder)) ||
      sameOrderElsewhere.isNotEmpty;
}

LocationAssessment assessLocation({
  required String location,
  required String so,
  required Iterable<StagingEntry> active,
  Iterable<ShippedEntry> shipped = const [],
  String? ignoreEntryId,
}) {
  final loc = locationKey(location);
  final order = orderKey(so);
  final eligible = active.where((entry) => entry.id != ignoreEntryId).toList();
  final occupants = eligible
      .where((entry) => locationKey(entry.location) == loc)
      .toList();
  final elsewhere = eligible
      .where(
        (entry) =>
            orderKey(entry.so) == order && locationKey(entry.location) != loc,
      )
      .toList();
  final history =
      shipped.where((entry) => locationKey(entry.location) == loc).toList()
        ..sort((a, b) {
          final left = a.shippedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.shippedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
  return LocationAssessment(
    location: location.trim(),
    sameOrder: so.trim(),
    occupants: occupants,
    sameOrderElsewhere: elsewhere,
    recentHistory: history.take(3).toList(),
  );
}

const rememberedSentinels = {
  'returned to stock',
  'consolidated',
  'unassigned carrier',
  'unknown',
  'none',
  'n/a',
};

List<String> filterRememberedValues(
  Iterable<String> values, {
  Iterable<String> hidden = const [],
}) {
  final hiddenKeys = hidden.map((value) => value.trim().toLowerCase()).toSet();
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final value = raw.trim();
    final key = value.toLowerCase();
    if (value.isEmpty ||
        rememberedSentinels.contains(key) ||
        hiddenKeys.contains(key) ||
        !seen.add(key)) {
      continue;
    }
    result.add(value);
  }
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}
