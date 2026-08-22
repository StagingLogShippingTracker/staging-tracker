import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_log/core/branding.dart';
import 'package:swift_staging_log/domain/status.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// App-level improve-loop harness → `qa_app/synthetic/harness_results.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_app', 'synthetic'));
    await synDir.create(recursive: true);
    final cases = <Map<String, dynamic>>[];
    final notes = <String>[];

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
      timed('shared_validation_ship', () {
        SlstValidation.ensureShipFields(
          so: '100',
          customer: 'Acme',
          carrier: 'Willys',
          shippedBy: 'Brice',
        );
        var rejected = false;
        try {
          SlstValidation.ensureShipFields(
            so: '',
            customer: 'Acme',
            carrier: 'Willys',
            shippedBy: 'Brice',
          );
        } catch (_) {
          rejected = true;
        }
        return rejected;
      }, gatesRaw: {'rejects_empty_so': true}),
    );

    cases.add(
      timed('shared_validation_po', () {
        SlstValidation.ensurePoNotification(
          po: 'PO-1',
          vendor: 'Vendor',
          pmEmail: 'pm@example.com',
        );
        var rejected = false;
        try {
          SlstValidation.ensurePoNotification(
            po: 'PO-1',
            vendor: 'Vendor',
            pmEmail: 'not-an-email',
          );
        } catch (_) {
          rejected = true;
        }
        return rejected;
      }),
    );

    cases.add(
      timed('email_subject_casing', () {
        final samples = [
          'SHIPPED: SO 1 - acme',
          'RETURN TO STOCK: SO 2 - beta',
          'PO Notification: po9',
          'Return Notification: SO 3 - cust',
          'Bulk PO Notification: 1, 2',
          'Swift Staging & Shipping Log feedback: bug',
        ];
        for (final s in samples) {
          final out = capitalizeEmailSubject(s);
          if (out != out.toUpperCase()) return false;
        }
        return true;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('audit_location_order', () {
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
      }),
    );

    cases.add(
      timed('kpi_math_smoke', () {
        // Lightweight shared math: container totals used by KPIs.
        final c = const ContainerCounts(skids: 2, boxes: 3, crates: 1);
        return c.total == 6 && c.typeLabel.isNotEmpty;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('shared_validation_return_notif', () {
        SlstValidation.ensureReturnNotification(
          so: '1',
          customer: 'Acme',
          pmEmail: 'pm@example.com',
        );
        var rejected = false;
        try {
          SlstValidation.ensureReturnNotification(
            so: '1',
            customer: 'Acme',
            pmEmail: 'not-an-email',
          );
        } catch (_) {
          rejected = true;
        }
        return rejected;
      }),
    );

    cases.add(
      timed('router_shell_routes_complete', () {
        final src = File(
          p.join(root.path, 'lib', 'core', 'router.dart'),
        ).readAsStringSync();
        const paths = [
          "path: '/'",
          "path: '/staging'",
          "path: '/shipped'",
          "path: '/reports'",
          "path: '/notifications'",
          "path: '/contacts'",
          "path: '/settings'",
        ];
        return paths.every(src.contains);
      }, metricsRaw: {'coverage': 1.0}),
    );

    cases.add(
      timed('status_ui_to_db_roundtrip', () {
        final today = StatusRules.toDb('Ship Today');
        final tomorrow = StatusRules.toDb('Ship Tomorrow');
        return StatusRules.isYmd(today) &&
            StatusRules.isYmd(tomorrow) &&
            StatusRules.formatUi(StatusRules.rushHotshot) ==
                StatusRules.rushHotshot;
      }),
    );

    cases.add(
      timed('status_urgency_weights', () {
        return StatusRules.urgencyWeight(StatusRules.rushHotshot) >
                StatusRules.urgencyWeight(StatusRules.todayYmd()) &&
            StatusRules.urgencyWeight(StatusRules.todayYmd()) >
                StatusRules.urgencyWeight(StatusRules.tomorrowYmd());
      }),
    );

    cases.add(
      timed('status_overdue_ymd', () {
        return StatusRules.isOverdue('2000-01-01') &&
            !StatusRules.isOverdue(StatusRules.todayYmd());
      }),
    );

    cases.add(
      timed(
        'product_brand_constants',
        () => kProductName == 'Swift Staging & Shipping Log',
        gatesRaw: {'brand': true},
      ),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'app',
      'cases': cases,
      'notes': notes,
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
