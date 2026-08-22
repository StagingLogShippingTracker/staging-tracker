import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_log/data/consolidation_undo.dart';
import 'package:swift_staging_log/domain/status.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// Staging / ship / return ops improve-loop harness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ops improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_ops', 'synthetic'));
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
      timed('container_counts_total', () {
        final original = ContainerCounts.parse('3 Skids, 2 Boxes');
        final a = const ContainerCounts(skids: 2, boxes: 1);
        final b = const ContainerCounts(skids: 1, boxes: 1);
        return (a + b).sameCounts(original) && original.total == 5;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('container_type_label', () {
        final c = const ContainerCounts(skids: 1, boxes: 2);
        return c.typeLabel.isNotEmpty && c.total == 3;
      }),
    );

    cases.add(
      timed('ship_fields_reject_empty', () {
        var rejected = false;
        try {
          SlstValidation.ensureShipFields(
            so: '1',
            customer: '',
            carrier: 'X',
            shippedBy: 'Y',
          );
        } catch (_) {
          rejected = true;
        }
        SlstValidation.ensureShipFields(
          so: '1',
          customer: 'C',
          carrier: 'X',
          shippedBy: 'Y',
        );
        return rejected;
      }, gatesRaw: {'rejects_empty_customer': true}),
    );

    cases.add(
      timed('return_fields_reject_empty', () {
        var rejected = false;
        try {
          SlstValidation.ensureReturnFields(
            pickedBy: 'A',
            returnedBy: 'B',
            reason: '',
          );
        } catch (_) {
          rejected = true;
        }
        return rejected;
      }),
    );

    cases.add(
      timed('so_advisories_smoke', () {
        // Shared SO formatting / validation surface used by advisories.
        final err = SlstValidation.requireNonEmpty('', 'SO');
        final ok = SlstValidation.requireNonEmpty('4398021', 'SO');
        return err != null && ok == null;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('container_parse_mixed', () {
        final c = ContainerCounts.parse('3 Skids, 2 Boxes');
        return c.skids == 3 && c.boxes == 2 && c.total == 5;
      }),
    );

    cases.add(
      timed('container_add_commutative', () {
        const a = ContainerCounts(skids: 2, boxes: 1);
        const b = ContainerCounts(skids: 1, crates: 1);
        return (a + b).sameCounts(b + a);
      }),
    );

    cases.add(
      timed('rpc_method_names_stable', () {
        final src = File(
          p.join(
            root.path,
            'packages',
            'swift_staging_shared',
            'lib',
            'src',
            'inventory_rpc.dart',
          ),
        ).readAsStringSync();
        const names = [
          'ship_staging_entry',
          'return_staging_to_stock',
          'split_staging',
          'consolidate_staging',
          'reverse_consolidation',
          'undo_shipment',
        ];
        return names.every(src.contains);
      }, metricsRaw: {'coverage': 1.0}),
    );

    cases.add(
      timed(
        'consolidate_undo_window_2m',
        () => consolidationUndoWindow == const Duration(minutes: 2),
      ),
    );

    cases.add(
      timed('status_urgency_weights', () {
        return StatusRules.urgencyWeight(StatusRules.rushHotshot) >= 60 &&
            StatusRules.urgencyWeight(StatusRules.tomorrowYmd()) == 40;
      }),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'ops',
      'cases': cases,
      'notes': <String>[],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
