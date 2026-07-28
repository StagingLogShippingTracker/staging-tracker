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
    final row = await _client
        .from('staging')
        .delete()
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'Staging entry $id was not found or could not be deleted.',
      );
    }
  }

  Future<StagingEntry> insert(Map<String, dynamic> payload) async {
    final row = await _client.from('staging').insert(payload).select().single();
    return StagingEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    final row = await _client
        .from('staging')
        .update(payload)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'Staging entry $id was not found or could not be updated.',
      );
    }
  }
}

class ShippedRepository {
  ShippedRepository(this._client);
  final SupabaseClient _client;

  Future<List<ShippedEntry>> fetchAll() async {
    final rows = await _client
        .from('shipped')
        .select()
        .order('shipped_at', ascending: false);
    return (rows as List)
        .map((e) => ShippedEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ShippedEntry> insert(Map<String, dynamic> payload) async {
    final row = await _client.from('shipped').insert(payload).select().single();
    return ShippedEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    final row = await _client
        .from('shipped')
        .update(payload)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'Shipped entry $id was not found or could not be updated.',
      );
    }
  }

  Future<void> delete(String id) async {
    final row = await _client
        .from('shipped')
        .delete()
        .eq('id', id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'Shipped entry $id was not found or could not be deleted.',
      );
    }
  }

  Future<ShippedEntry?> getById(String id) async {
    final row = await _client
        .from('shipped')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ShippedEntry.fromMap(Map<String, dynamic>.from(row));
  }
}

class ChangelogRepository {
  ChangelogRepository(this._client);
  final SupabaseClient _client;

  Future<void> log(String table, String action) async {
    final email = _client.auth.currentUser?.email;
    final user = (email == null || email.isEmpty)
        ? 'Guest'
        : email.split('@').first;
    await _client.from('changelog').insert({
      'table_name': table,
      'action': action,
      'user_email': user,
    });
  }

  Future<List<ChangelogEntry>> recent({int limit = 200}) async {
    final rows = await _client
        .from('changelog')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => ChangelogEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ChangelogEntry>> forOrder(String so) async {
    final needle = so.trim();
    final pattern =
        '%${needle.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await _client
        .from('changelog')
        .select()
        .ilike('action', pattern)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => ChangelogEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
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
    await _client.storage
        .from(AppConfig.freightPhotosBucket)
        .uploadBinary(
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
