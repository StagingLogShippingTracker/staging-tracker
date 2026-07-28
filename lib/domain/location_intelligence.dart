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

/// Combined partial-box bay: replaces B-02-A-1/A-2/B-1/B-2.
const b02PartialLocation = 'B-02-Partial';

bool isB02PartialLocation(String location) =>
    locationKey(location) == locationKey(b02PartialLocation);

/// Shared bay for partial boxes — occupancy warnings only apply when the
/// inbound load includes skids or crates (wrong container class for this bay).
bool partialBayRequiresConflictWarning(ContainerCounts? containers) {
  if (containers == null) return false;
  return containers.skids > 0 || containers.crates > 0;
}

const _b02PartialSlots = ['B-02-A-1', 'B-02-A-2', 'B-02-B-1', 'B-02-B-2'];

/// Slot locations superseded by [b02PartialLocation] — hide from aisle picks.
const supersededAisleLocations = {
  'B-02-A-1',
  'B-02-A-2',
  'B-02-B-1',
  'B-02-B-2',
};

/// Built-in aisle bins always offered (roster may be empty on a fresh device).
const seededAisleLocations = [b02PartialLocation];

/// Standard bin: `A-01-A-1` / dual-skid `A-01-A-1+2`.
/// Special bay: `B-02-Partial` (partial boxes for aisle B bay 02).
final aisleLocationPattern = RegExp(
  r'^(?:B-02-PARTIAL|([A-Z])-(\d{2})-([A-F])-(1|2|1\+2))$',
  caseSensitive: false,
);

final _standardAislePattern = RegExp(
  r'^([A-Z])-(\d{2})-([A-F])-(1|2|1\+2)$',
  caseSensitive: false,
);

final _b02PartialPattern = RegExp(
  r'^B-02-PARTIAL$',
  caseSensitive: false,
);

class AisleLocation {
  const AisleLocation({
    required this.aisle,
    required this.bay,
    required this.level,
    required this.suffix,
    this.isPartialBay = false,
  });

  final String aisle;
  final int bay;
  final String level;
  final String suffix;

  /// True for [b02PartialLocation] — spans levels A+B, sides 1+2.
  final bool isPartialBay;

  /// Dual-width skid occupying both side-1 and side-2 of one level.
  bool get isDualSlot => !isPartialBay && suffix == '1+2';

  String get bayKey => '$aisle-${bay.toString().padLeft(2, '0')}';

  String get normalized => isPartialBay
      ? b02PartialLocation
      : '$aisle-${bay.toString().padLeft(2, '0')}-$level-$suffix';

  /// Physical slot keys this location occupies on the floor map.
  List<String> get coveredSlots {
    if (isPartialBay) {
      return List<String>.from(_b02PartialSlots);
    }
    final bay = bayKey;
    if (isDualSlot) {
      return ['$bay-$level-1', '$bay-$level-2'];
    }
    return ['$bay-$level-$suffix'];
  }
}

AisleLocation? parseAisleLocation(String raw) {
  final value = raw.trim().toUpperCase();
  if (value.isEmpty) return null;

  if (_b02PartialPattern.hasMatch(value)) {
    return const AisleLocation(
      aisle: 'B',
      bay: 2,
      level: 'PARTIAL',
      suffix: '',
      isPartialBay: true,
    );
  }

  final match = _standardAislePattern.firstMatch(value);
  if (match == null) return null;
  return AisleLocation(
    aisle: match.group(1)!,
    bay: int.parse(match.group(2)!),
    level: match.group(3)!,
    suffix: match.group(4)!,
  );
}

/// Uppercase keys that count as the same physical floor space.
Set<String> locationOccupancyKeys(String location) {
  final key = locationKey(location);
  final parsed = parseAisleLocation(location);
  if (parsed == null) return {key};

  final keys = <String>{key, ...parsed.coveredSlots.map(locationKey)};
  // Legacy slot labels and B-02-Partial share one occupancy group.
  if (parsed.isPartialBay ||
      supersededAisleLocations.contains(key) ||
      parsed.coveredSlots.any(
        (s) => supersededAisleLocations.contains(locationKey(s)),
      )) {
    keys.add(locationKey(b02PartialLocation));
    keys.addAll(supersededAisleLocations);
  }
  return keys;
}

bool locationsShareFloorSpace(String a, String b) {
  return locationOccupancyKeys(a).intersection(locationOccupancyKeys(b)).isNotEmpty;
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

/// Drop superseded B-02 A/B slots; ensure [b02PartialLocation] is present.
List<String> normalizeAisleSuggestionList(Iterable<String> values) {
  final filtered = filterRememberedValues(values).where((value) {
    final key = locationKey(value);
    return !supersededAisleLocations.contains(key);
  });
  return filterRememberedValues([...seededAisleLocations, ...filtered]);
}

/// Most recent non-empty customer for [so] across active staging and shipped.
String? mostRecentCustomerForSo({
  required Iterable<StagingEntry> staging,
  required Iterable<ShippedEntry> shipped,
  required String so,
}) {
  final key = orderKey(so);
  if (key.isEmpty) return null;

  final candidates = <({String customer, DateTime? at})>[
    for (final e in staging)
      if (orderKey(e.so) == key && e.customer.trim().isNotEmpty)
        (customer: e.customer.trim(), at: e.entryDate),
    for (final e in shipped)
      if (orderKey(e.so) == key && e.customer.trim().isNotEmpty)
        (customer: e.customer.trim(), at: e.shippedAt),
  ];
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final aAt = a.at;
    final bAt = b.at;
    if (aAt == null && bAt == null) return 0;
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    return bAt.compareTo(aAt);
  });
  return candidates.first.customer;
}

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
  final locKeys = locationOccupancyKeys(location);
  final order = orderKey(so);
  final eligible = active.where((entry) => entry.id != ignoreEntryId).toList();
  final occupants = eligible
      .where((entry) => locationsShareFloorSpace(entry.location, location))
      .toList();
  final elsewhere = eligible
      .where(
        (entry) =>
            orderKey(entry.so) == order &&
            !locationsShareFloorSpace(entry.location, location),
      )
      .toList();
  final history =
      shipped
          .where((entry) => locKeys.contains(locationKey(entry.location)))
          .toList()
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
