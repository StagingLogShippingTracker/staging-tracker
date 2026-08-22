import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:swift_staging_shared/swift_staging_shared.dart';

/// Auth / watch-pair / RLS static harness → qa_auth/synthetic/harness_results.json.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth improve-loop matrix', () async {
    final root = Directory.current;
    final synDir = Directory(p.join(root.path, 'qa_auth', 'synthetic'));
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

    bool scanClients(RegExp rx) {
      final roots = [
        Directory(p.join(root.path, 'lib')),
        Directory(p.join(root.path, 'apps', 'wear', 'lib')),
        Directory(p.join(root.path, 'packages', 'swift_staging_shared', 'lib')),
      ];
      for (final dir in roots) {
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          final text = f.readAsStringSync();
          if (rx.hasMatch(text)) return true;
        }
      }
      return false;
    }

    cases.add(
      timed(
        'no_service_role_in_clients',
        () => !scanClients(
          RegExp(r'service_role|SERVICE_ROLE_KEY', caseSensitive: false),
        ),
        gatesRaw: {'no_service_role': true},
        metricsRaw: {'integrity': true},
      ),
    );

    cases.add(
      timed(
        'no_make_webhook_in_clients',
        () => !scanClients(
          RegExp(
            r'MAKE_EMAIL_WEBHOOK_URL|hook\.eu[12]\.make\.com|hook\.us[12]\.make\.com',
            caseSensitive: false,
          ),
        ),
        gatesRaw: {'no_webhook': true},
      ),
    );

    cases.add(
      timed('watch_pair_create_redeem_split', () {
        final src = File(
          p.join(
            root.path,
            'packages',
            'swift_staging_shared',
            'lib',
            'src',
            'watch_pairing.dart',
          ),
        ).readAsStringSync();
        return src.contains("action': 'create'") &&
            src.contains("action': 'redeem'") &&
            src.contains('createCode') &&
            src.contains('redeemCode');
      }, gatesRaw: {'create_and_redeem_distinct': true}),
    );

    cases.add(
      timed('watch_pair_six_digit_contract', () {
        final src = File(
          p.join(
            root.path,
            'supabase',
            'functions',
            'watch-pair',
            'index.ts',
          ),
        ).readAsStringSync();
        return src.contains(r'/^\d{6}$/') || src.contains(r'/^\d{6}$/');
      }),
    );

    cases.add(
      timed('rls_staging_select_authenticated', () {
        final migDir = Directory(p.join(root.path, 'supabase', 'migrations'));
        var found = false;
        for (final f in migDir.listSync().whereType<File>()) {
          if (!f.path.endsWith('.sql')) continue;
          final t = f.readAsStringSync().toLowerCase();
          if (t.contains('staging_select_authenticated') ||
              (t.contains('authenticated') &&
                  t.contains('staging') &&
                  t.contains('select'))) {
            found = true;
            break;
          }
        }
        return found;
      }),
    );

    cases.add(
      timed('rls_writes_authenticated', () {
        final migDir = Directory(p.join(root.path, 'supabase', 'migrations'));
        var found = false;
        for (final f in migDir.listSync().whereType<File>()) {
          if (!f.path.endsWith('.sql')) continue;
          final t = f.readAsStringSync().toLowerCase();
          if (t.contains('authenticated') &&
              (t.contains('insert') || t.contains('update')) &&
              t.contains('policy')) {
            found = true;
            break;
          }
        }
        return found;
      }),
    );

    cases.add(
      timed(
        'app_config_anon_key_only',
        () {
          final key = AppConfig.supabaseAnonKey;
          // JWT payload role claim is anon in default key; never service_role string.
          return key.isNotEmpty &&
              !key.toLowerCase().contains('service_role') &&
              AppConfig.supabaseUrl.startsWith('https://');
        },
        metricsRaw: {'integrity': true},
      ),
    );

    cases.add(
      timed('login_empty_field_messages', () {
        final src = File(
          p.join(root.path, 'lib', 'features', 'auth', 'login_screen.dart'),
        ).readAsStringSync();
        return src.contains('Enter your email and password.') &&
            src.contains('Enter your email address.') &&
            src.contains('Enter your password.') &&
            src.contains('email_not_confirmed');
      }),
    );

    final out = {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'domain': 'auth',
      'cases': cases,
      'notes': [
        'Watch create is phone/Windows; redeem is Wear only.',
        'Clients must never ship service_role or Make webhook URL.',
      ],
    };
    await File(p.join(synDir.path, 'harness_results.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(out),
    );

    final failed = cases.where((c) => c['ok'] != true).map((c) => c['case_id']);
    expect(failed, isEmpty, reason: 'failed cases: $failed');
  });
}
