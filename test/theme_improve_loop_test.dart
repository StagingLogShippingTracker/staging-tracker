import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_log/core/branding.dart';
import 'package:swift_staging_log/core/theme.dart';
import 'package:swift_staging_log/data/theme_preference.dart';

/// Theme / brand harness → qa_theme/synthetic/harness_results.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_theme', 'synthetic'));
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
      timed(
        'product_name_official',
        () => kProductName == 'Swift Staging & Shipping Log',
        gatesRaw: {'brand_exact': true},
      ),
    );

    cases.add(
      timed(
        'product_compact_name',
        () => kProductCompactName == 'Staging Log',
      ),
    );

    cases.add(
      timed(
        'theme_preference_modes',
        () => kDarkModePrefsKey == 'slst.theme.dark',
      ),
    );

    cases.add(
      timed('status_color_rush_distinct', () {
        final rush = statusStyleFor(
          uiLabel: 'Rush/Hotshot',
          isDateStatus: false,
          overdue: false,
          brightness: Brightness.dark,
        );
        final today = statusStyleFor(
          uiLabel: 'Ship Today',
          isDateStatus: false,
          overdue: false,
          brightness: Brightness.dark,
        );
        return rush.accent != today.accent &&
            IndustrialTheme.hotRed != IndustrialTheme.mintGreen;
      }, metricsRaw: {'integrity': true}),
    );

    cases.add(
      timed('no_bare_slst_product_title', () {
        // Product chrome title must be Swift brand, not bare "SLST".
        final branding = File(
          p.join(root.path, 'lib', 'core', 'branding.dart'),
        ).readAsStringSync();
        return branding.contains("Swift Staging & Shipping Log") &&
            !RegExp(r"kProductName\s*=\s*'SLST'").hasMatch(branding);
      }),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'theme',
      'cases': cases,
      'notes': ['Brand strings must stay Swift Staging & Shipping Log.'],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
