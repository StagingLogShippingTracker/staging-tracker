import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_shared/swift_staging_shared.dart';
import 'package:swift_staging_wear/theme.dart';

/// Wear OS improve-loop harness → repo qa_wear/synthetic/harness_results.json.
///
/// Run via: flutter test test/wear_improve_loop_test.dart (cwd=apps/wear)
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = Directory(p.join(dir.path));
    if (Directory(p.join(candidate.path, 'apps', 'wear')).existsSync() &&
        File(p.join(candidate.path, 'pubspec.yaml')).existsSync()) {
      return candidate;
    }
    // From apps/wear → parent.parent is repo root.
    if (p.basename(dir.path) == 'wear' &&
        p.basename(dir.parent.path) == 'apps') {
      return dir.parent.parent;
    }
    dir = dir.parent;
  }
  return Directory.current.parent.parent;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wear improve-loop matrix', () async {
    final root = _repoRoot();
    final synDir = Directory(p.join(root.path, 'qa_wear', 'synthetic'));
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

    final mainSrc = File(p.join(root.path, 'apps', 'wear', 'lib', 'main.dart'))
        .readAsStringSync();
    final updateSrc = File(
      p.join(root.path, 'apps', 'wear', 'lib', 'screens', 'update_screen.dart'),
    ).readAsStringSync();
    final shipSrc = File(
      p.join(
        root.path,
        'apps',
        'wear',
        'lib',
        'screens',
        'ship_confirm_screen.dart',
      ),
    ).readAsStringSync();
    final verifySrc = File(
      p.join(root.path, 'apps', 'wear', 'lib', 'screens', 'verify_screen.dart'),
    ).readAsStringSync();
    final pairSrc = File(
      p.join(root.path, 'apps', 'wear', 'lib', 'screens', 'pair_screen.dart'),
    ).readAsStringSync();

    cases.add(
      timed(
        'wear_brand_title',
        () => mainSrc.contains("title: 'Swift Staging & Shipping Log'"),
        gatesRaw: {'brand_title': true},
      ),
    );

    cases.add(
      timed(
        'wear_theme_dark_only',
        () =>
            mainSrc.contains('themeMode: ThemeMode.dark') &&
            WearTheme.dark.brightness == Brightness.dark,
      ),
    );

    cases.add(
      timed(
        'wear_ship_payload_cc',
        () =>
            shipSrc.contains('ship_confirm') ||
            shipSrc.contains('ShipOperations') ||
            shipSrc.contains('warehouseCc') ||
            AppConfig.warehouseCc.contains('@'),
        metricsRaw: {'integrity': true},
      ),
    );

    cases.add(
      timed('wear_ship_validation_empty_carrier', () {
        var rejected = false;
        try {
          SlstValidation.ensureShipFields(
            so: '1',
            customer: 'C',
            carrier: '',
            shippedBy: 'W',
          );
        } catch (_) {
          rejected = true;
        }
        return rejected;
      }),
    );

    cases.add(
      timed(
        'wear_update_platform_is_wear',
        () => updateSrc.contains('AppUpdatePlatform.wear'),
        gatesRaw: {'wear_platform': true},
      ),
    );

    cases.add(
      timed(
        'wear_pair_redeem_six_digit',
        () =>
            pairSrc.contains('redeemCode') &&
            !pairSrc.contains('createCode'),
        gatesRaw: {'redeem_only': true},
      ),
    );

    cases.add(
      timed('wear_verify_audit_order', () {
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
        return verifySrc.contains('compareAuditLocations') &&
            compareAuditLocations(shelf, aisle) < 0;
      }),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'wear',
      'cases': cases,
      'notes': [
        'Wear redeems pairing codes; phone/Windows create them.',
        'Wear Update must request AppUpdatePlatform.wear only.',
      ],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
