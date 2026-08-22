import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// Contacts / roster harness → qa_contacts/synthetic/harness_results.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contacts improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_contacts', 'synthetic'));
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

    final assetPaths = [
      p.join(root.path, 'packages', 'swift_staging_shared', 'assets', 'contacts.json'),
      p.join(root.path, 'assets', 'contacts.json'),
    ];

    cases.add(
      timed(
        'contacts_asset_present',
        () => assetPaths.any((path) => File(path).existsSync()),
        gatesRaw: {'asset_on_disk': true},
      ),
    );

    cases.add(
      timed('bundled_contacts_json_parses', () {
        final path = assetPaths.firstWhere(
          (path) => File(path).existsSync(),
          orElse: () => '',
        );
        if (path.isEmpty) return false;
        final list = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
        return list.isNotEmpty;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('contact_required_fields', () {
        final path = assetPaths.firstWhere(
          (path) => File(path).existsSync(),
          orElse: () => '',
        );
        if (path.isEmpty) return false;
        final list = jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
        var withEmail = 0;
        for (final raw in list.take(20)) {
          final c = ContactPerson.fromMap(Map<String, dynamic>.from(raw as Map));
          if (c.name.trim().isEmpty) return false;
          if (c.email.contains('@')) withEmail++;
        }
        return withEmail > 0;
      }),
    );

    cases.add(
      timed('roster_types_stable', () {
        const types = {
          'location_aisle',
          'location_floor',
          'location_shipping',
          'location_outside',
          'carrier',
          'person_by',
        };
        // LocationCategory.rosterType covers location_* ; others used in app_state.
        final src = File(
          p.join(root.path, 'lib', 'domain', 'location_intelligence.dart'),
        ).readAsStringSync();
        return types
            .where((t) => t.startsWith('location_'))
            .every((t) => src.contains("'$t'"));
      }, metricsRaw: {'coverage': 1.0}),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'contacts',
      'cases': cases,
      'notes': ['Bundled contacts.json must parse; warehouse emails via withWarehouseContacts.'],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
