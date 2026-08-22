import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_log/domain/location_intelligence.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// Location / map improve-loop harness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('location improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_location', 'synthetic'));
    await synDir.create(recursive: true);
    final cases = <Map<String, dynamic>>[];

    Map<String, dynamic> timed(
      String caseId,
      bool Function() run, {
      Map<String, dynamic>? metricsRaw,
      Map<String, bool>? gatesRaw,
    }) {
      final t0 = DateTime.now();
      var ok = false;
      String? err;
      try {
        ok = run();
      } catch (e) {
        err = '$e';
        ok = false;
      }
      return {
        'case_id': caseId,
        'ok': ok,
        'duration_ms': DateTime.now().difference(t0).inMilliseconds,
        if (metricsRaw != null) 'metrics_raw': metricsRaw,
        if (gatesRaw != null) 'gates_raw': gatesRaw,
        if (err != null) 'error': err,
      };
    }

    cases.add(
      timed('location_parse_aisle', () {
        final parsed = parseAisleLocation('a-01-b-1');
        return parsed?.normalized == 'A-01-B-1' &&
            classifyLocation('A-01-A-1') == LocationCategory.aisle;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('location_category_filter', () {
        final samples = <String, LocationCategory>{
          'A-01-A-1': LocationCategory.aisle,
          'W-2 SHIPPING': LocationCategory.shipping,
          'Outside west yard': LocationCategory.outside,
          'South Wall': LocationCategory.floor,
          'SW 3': LocationCategory.floor,
        };
        for (final e in samples.entries) {
          if (classifyLocation(e.key) != e.value) return false;
        }
        return true;
      }, metricsRaw: {'coverage': 1.0}),
    );

    cases.add(
      timed('map_pick_mode_blocks_freetext', () {
        // Map categories expose a pick mode; Outside does not (tiles / other).
        final mapCats = [
          LocationCategory.aisle,
          LocationCategory.floor,
          LocationCategory.shipping,
        ];
        for (final c in mapCats) {
          if (c.mapPickMode == null) return false;
        }
        if (LocationCategory.outside.mapPickMode != null) return false;
        // Aisle mode cannot pick floor-only zones.
        return !FloorMapZones.isPickable(
              WarehouseMapPickMode.aisle,
              FloorMapZones.boxRack,
            ) &&
            FloorMapZones.isPickable(
              WarehouseMapPickMode.shipping,
              FloorMapZones.shippingAreas,
            );
      }, gatesRaw: {
        'aisle_has_map_mode': true,
        'floor_has_map_mode': true,
        'shipping_has_map_mode': true,
        'outside_no_map_mode': true,
      }),
    );

    cases.add(
      timed('outside_tiles_ok', () {
        return classifyLocation('Outside west yard') ==
                LocationCategory.outside &&
            LocationCategory.outside.mapPickMode == null;
      }),
    );

    cases.add(
      timed('floor_zone_pickable_matrix', () {
        return FloorMapZones.isPickable(
              WarehouseMapPickMode.floor,
              FloorMapZones.corpDrop,
            ) &&
            FloorMapZones.isPickable(
              WarehouseMapPickMode.floor,
              FloorMapZones.boxRack,
            ) &&
            !FloorMapZones.isPickable(
              WarehouseMapPickMode.aisle,
              FloorMapZones.boxRack,
            ) &&
            FloorMapZones.isPickable(
              WarehouseMapPickMode.shipping,
              FloorMapZones.shippingAreas,
            );
      }, metricsRaw: {'coverage': 1.0}),
    );

    cases.add(
      timed(
        'canonical_location_labels',
        () =>
            FloorMapZones.canonicalLocation(FloorMapZones.corpDrop) ==
                'Corp Drop-Off' &&
            FloorMapZones.canonicalLocation(FloorMapZones.shippingBoxRack) ==
                'S.Box',
      ),
    );

    cases.add(
      timed(
        'b02_partial_supersedes_slots',
        () =>
            supersededAisleLocations.contains('B-02-A-1') &&
            isB02PartialLocation(b02PartialLocation),
      ),
    );

    cases.add(
      timed('partial_bay_conflict_skids_crates', () {
        return partialBayRequiresConflictWarning(
              const ContainerCounts(skids: 1),
            ) &&
            !partialBayRequiresConflictWarning(
              const ContainerCounts(boxes: 2),
            );
      }),
    );

    cases.add(
      timed(
        'drive_gap_bays_reserved',
        () =>
            longAisleDriveGaps.contains(7) &&
            longAisleDriveGaps.contains(13) &&
            longAisleDriveGaps.contains(24),
      ),
    );

    cases.add(
      timed(
        'seeded_outside_no_freetext',
        () =>
            seededOutsideLocations.length == 2 &&
            seededOutsideLocations.contains('Outside') &&
            seededOutsideLocations.contains('Yard'),
        gatesRaw: {'no_freetext_outside_seeds': true},
      ),
    );

    cases.add(
      timed(
        'classify_shipping_w2',
        () => classifyLocation('W-2 SHIPPING') == LocationCategory.shipping,
      ),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'location',
      'cases': cases,
      'notes': [
        'Map-first: aisle/floor/shipping use WarehouseMapPickMode; outside does not.',
      ],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
