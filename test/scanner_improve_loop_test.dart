import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_log/features/scanner/models/scan_models.dart';
import 'package:swift_staging_log/features/scanner/services/offline_ocr_service.dart';

/// Scanner / OCR harness → qa_scanner/synthetic/harness_results.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scanner improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_scanner', 'synthetic'));
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
      timed('scan_work_state_machine', () {
        const expected = {
          ScanWork.idle,
          ScanWork.detecting,
          ScanWork.processing,
          ScanWork.recognizing,
          ScanWork.failed,
        };
        return ScanWork.values.toSet().containsAll(expected) &&
            ScanWork.values.length == 5;
      }, metricsRaw: {'coverage': 1.0}),
    );

    cases.add(
      timed(
        'document_corners_full_default',
        () => DocumentCorners.full.isValid || DocumentCorners.full.points.length == 4,
      ),
    );

    cases.add(
      timed('enhancement_enum_stable', () {
        final labels = ScanEnhancement.values.map((e) => e.label).toSet();
        return labels.contains('Original') &&
            labels.contains('Document') &&
            labels.contains('B&W');
      }),
    );

    cases.add(
      timed('ocr_result_model_fields', () {
        const r = ScanOcrResult(text: 'SO 1', confidence: 0.9, lineCount: 1);
        return r.text == 'SO 1' && r.confidence == 0.9 && r.lineCount == 1;
      }),
    );

    cases.add(
      timed('offline_ocr_service_constructs', () {
        OfflineOcrService();
        return true;
      }),
    );

    cases.add(
      timed('scan_screen_exports', () {
        // Keep scanner entrypoint importable (regression if screen deleted).
        final src = File(
          p.join(
            root.path,
            'lib',
            'features',
            'scanner',
            'scanner_screen.dart',
          ),
        ).readAsStringSync();
        return src.contains('class ScanDocumentButton');
      }),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'scanner',
      'cases': cases,
      'notes': ['Scanner pipeline state machine + OCR models.'],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
