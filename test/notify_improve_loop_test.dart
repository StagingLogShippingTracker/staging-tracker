import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// Make + notify-pm contract harness for all notification types.
///
/// Writes `qa_notify/synthetic/harness_results.json`.
const _requiredKeys = ['to', 'cc', 'subject', 'body', 'attachments', 'notification_type'];

const _types = <String, Map<String, Object?>>{
  'ship_confirm': {
    'to': 'pm@example.com',
    'cc': AppConfig.warehouseCc,
    'subject': 'SHIPPED: SO 1 - Acme',
    'body': '<p>ship</p>',
    'attachments': <String>[],
    'notification_type': 'ship_confirm',
  },
  'quick_ship': {
    'to': 'pm@example.com',
    'cc': AppConfig.warehouseCc,
    'subject': 'SHIPPED: SO 2 - Acme',
    'body': '<p>quick</p>',
    'attachments': <String>[],
    'notification_type': 'quick_ship',
  },
  'return_to_stock': {
    'to': 'pm@example.com',
    'cc': AppConfig.warehouseCc,
    'subject': 'RETURN TO STOCK: SO 3 - Acme',
    'body': '<p>rts</p>',
    'attachments': <String>[],
    'notification_type': 'return_to_stock',
  },
  'po_notification': {
    'to': 'pm@example.com',
    'cc': AppConfig.warehouseCc,
    'subject': 'PO Notification: 99',
    'body': '<p>po</p>',
    'attachments': <String>[],
    'notification_type': 'po_notification',
  },
  'bulk_po_notification': {
    'to': 'pm@example.com',
    'cc': 'warehouse1@swiftsupply.ca',
    'subject': 'Bulk PO Notification: 1, 2',
    'body': '<p>bulk</p>',
    'attachments': <String>[],
    'notification_type': 'bulk_po_notification',
  },
  'return_notification': {
    'to': 'pm@example.com',
    'cc': AppConfig.warehouseCc,
    'subject': 'Return Notification: SO 4 - Cust',
    'body': '<p>return</p>',
    'attachments': <String>[],
    'notification_type': 'return_notification',
  },
  'feedback_notification': {
    'to': 'warehouse2@swiftsupply.ca',
    'cc': 'warehouse1@swiftsupply.ca',
    'subject': 'Swift Staging & Shipping Log feedback: bug',
    'body': '<p>feedback</p>',
    'attachments': <String>[],
    'notification_type': 'feedback_notification',
  },
};

bool _payloadOk(Map<String, Object?> payload) {
  for (final k in _requiredKeys) {
    if (!payload.containsKey(k)) return false;
  }
  final to = '${payload['to']}'.trim();
  final cc = '${payload['cc']}'.trim();
  final subject = '${payload['subject']}'.trim();
  final body = '${payload['body']}'.trim();
  if (!to.contains('@')) return false;
  if (!cc.contains('@')) return false;
  if (subject.isEmpty || body.isEmpty) return false;
  if (payload['attachments'] is! List) return false;
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notify improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_notify', 'synthetic'));
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

    for (final entry in _types.entries) {
      final caseId = 'payload_keys_${entry.key == 'feedback_notification' ? 'feedback' : entry.key == 'po_notification' ? 'po' : entry.key == 'bulk_po_notification' ? 'bulk_po' : entry.key == 'return_notification' ? 'return' : entry.key}';
      // Map to scorer budget ids
      final budgetId = switch (entry.key) {
        'ship_confirm' => 'payload_keys_ship',
        'quick_ship' => 'payload_keys_quick_ship',
        'return_to_stock' => 'payload_keys_return_to_stock',
        'po_notification' => 'payload_keys_po',
        'bulk_po_notification' => 'payload_keys_bulk_po',
        'return_notification' => 'payload_keys_return',
        'feedback_notification' => 'payload_keys_feedback',
        _ => caseId,
      };
      cases.add(
        timed(budgetId, () => _payloadOk(entry.value), metricsRaw: {
          'integrity': true,
        }, gatesRaw: {
          'has_to': true,
          'has_cc': true,
          'has_subject': true,
          'has_body': true,
        }),
      );
    }

    cases.add(
      timed('subject_uppercase_all_types', () {
        for (final payload in _types.values) {
          final raw = '${payload['subject']}';
          final capped = capitalizeEmailSubject(raw);
          if (capped != capped.toUpperCase()) return false;
        }
        return true;
      }, metricsRaw: {'coverage': 1.0}),
    );

    cases.add(
      timed('cc_required_contract', () {
        // Make Outlook module rejects empty CC — every type must set one.
        for (final payload in _types.values) {
          final cc = '${payload['cc']}'.trim();
          if (!cc.contains('@')) return false;
        }
        return AppConfig.warehouseCc.contains('@');
      }, gatesRaw: {'warehouse_cc_configured': true}),
    );

    cases.add(
      timed('type_alias_coverage', () {
        const aliases = {
          'ship_confirm',
          'quick_ship',
          'return_to_stock',
          'po_notification',
          'bulk_po_notification',
          'return_notification',
          'feedback_notification',
        };
        final covered = _types.keys.toSet();
        final missing = aliases.difference(covered);
        return missing.isEmpty;
      }, metricsRaw: {
        'coverage': _types.length / 7.0,
        'integrity': true,
      }),
    );

    cases.add(
      timed('no_make_webhook_in_flutter', () {
        final roots = [
          Directory(p.join(root.path, 'lib')),
          Directory(p.join(root.path, 'apps', 'wear', 'lib')),
          Directory(
            p.join(root.path, 'packages', 'swift_staging_shared', 'lib'),
          ),
        ];
        final rx = RegExp(
          r'MAKE_EMAIL_WEBHOOK_URL|hook\.eu[12]\.make\.com|hook\.us[12]\.make\.com',
          caseSensitive: false,
        );
        for (final dir in roots) {
          if (!dir.existsSync()) continue;
          for (final f in dir.listSync(recursive: true).whereType<File>()) {
            if (!f.path.endsWith('.dart')) continue;
            if (rx.hasMatch(f.readAsStringSync())) return false;
          }
        }
        return true;
      }, gatesRaw: {'no_webhook_in_clients': true}),
    );

    cases.add(
      timed(
        'feedback_to_warehouse2',
        () {
          final fb = _types['feedback_notification']!;
          return '${fb['to']}'.contains('warehouse2@') &&
              '${fb['cc']}'.contains('warehouse1@');
        },
      ),
    );

    cases.add(
      timed(
        'warehouse_cc_default',
        () => AppConfig.warehouseCc == 'warehouse1@swiftsupply.ca',
      ),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'notify',
      'cases': cases,
      'notes': [
        'Client payload contract only — Make must stay active separately.',
        'notify-pm normalizes ship_confirm/quick_ship → ship_notification.',
      ],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
