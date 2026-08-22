import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// Reports / SVR / audit harness → qa_reports/synthetic/harness_results.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_reports', 'synthetic'));
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
      timed('audit_location_order_box_before_aisle', () {
        final aisle = StagingEntry(
          id: 'a',
          so: '1',
          customer: 'A',
          status: 'Staged',
          location: 'A-01-A-1',
          type: '1 Skid',
          qty: 1,
        );
        final shelf = StagingEntry(
          id: 'b',
          so: '2',
          customer: 'A',
          status: 'Staged',
          location: 'BOX SHELF',
          type: '1 Box',
          qty: 1,
        );
        return compareAuditLocations(shelf, aisle) < 0;
      }, gatesRaw: {'box_before_aisle': true}),
    );

    cases.add(
      timed('audit_mode_enum_roundtrip', () {
        for (final m in AuditMode.values) {
          if (auditModeFromName(auditModeName(m)) != m) return false;
        }
        return true;
      }),
    );

    cases.add(
      timed('loc_key_priority_bands', () {
        final box = locKey('BOX SHELF').first as int;
        final aisle = locKey('A-01-A-1').first as int;
        final ship = locKey('W-2 SHIPPING').first as int;
        return box == 1 && aisle == 3 && ship == 5;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('wear_svr_same_comparator', () {
        final wearVerify = File(
          p.join(root.path, 'apps', 'wear', 'lib', 'screens', 'verify_screen.dart'),
        );
        if (!wearVerify.existsSync()) return false;
        final text = wearVerify.readAsStringSync();
        return text.contains('compareAuditLocations');
      }),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'reports',
      'cases': cases,
      'notes': ['SVR walk order must match Windows/Android and Wear.'],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
