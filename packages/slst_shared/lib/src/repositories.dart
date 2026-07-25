import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'app_config.dart';
import 'email_subjects.dart';
import 'models.dart';

class StagingRepository {
  StagingRepository(this._client);
  final SupabaseClient _client;

  Future<List<StagingEntry>> fetchAll() async {
    final rows = await _client
        .from('staging')
        .select()
        .order('entry_date', ascending: false);
    return (rows as List)
        .map((e) => StagingEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> delete(String id) async {
    await _client.from('staging').delete().eq('id', id);
  }
}

class ShippedRepository {
  ShippedRepository(this._client);
  final SupabaseClient _client;

  Future<void> insert(Map<String, dynamic> payload) async {
    await _client.from('shipped').insert(payload);
  }
}

class ChangelogRepository {
  ChangelogRepository(this._client);
  final SupabaseClient _client;

  Future<void> log(String table, String action) async {
    final email = _client.auth.currentUser?.email;
    await _client.from('changelog').insert({
      'table_name': table,
      'action': action,
      'user_email': email,
    });
  }
}

class RosterRepository {
  RosterRepository(this._client);
  final SupabaseClient _client;

  Future<List<String>> valuesFor(String rosterType) async {
    final rows = await _client
        .from('dropdown_roster')
        .select('value')
        .eq('roster_type', rosterType)
        .order('value');
    return (rows as List)
        .map((e) => '${(e as Map)['value']}')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> remember(String rosterType, String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    await _client.from('dropdown_roster').upsert({
      'roster_type': rosterType,
      'value': v,
    }, onConflict: 'roster_type,value');
  }
}

class PhotoStorage {
  PhotoStorage(this._client);
  final SupabaseClient _client;
  final _uuid = const Uuid();

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String folder = 'uploads',
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$folder/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}_$safe';
    await _client.storage.from(AppConfig.freightPhotosBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _imageContentType(fileName),
          ),
        );
    return path;
  }
}

String _imageContentType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  return 'image/jpeg';
}

class NotifyRepository {
  NotifyRepository(this._client);
  final SupabaseClient _client;

  Future<void> sendPmNotification(Map<String, dynamic> payload) async {
    final body = Map<String, dynamic>.from(payload);
    final subject = body['subject'];
    if (subject is String && subject.trim().isNotEmpty) {
      body['subject'] = capitalizeEmailSubject(subject);
    }
    final res = await _client.functions.invoke('notify-pm', body: body);
    if (res.status >= 400) {
      throw Exception('Notification failed (${res.status}): ${res.data}');
    }
  }
}

Future<List<ContactPerson>> loadBundledContacts() async {
  final raw = await rootBundle.loadString(
    'packages/slst_shared/assets/contacts.json',
  );
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => ContactPerson.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
}
