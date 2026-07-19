import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../domain/models.dart';

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

  Future<StagingEntry> insert(Map<String, dynamic> payload) async {
    final row = await _client.from('staging').insert(payload).select().single();
    return StagingEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    await _client.from('staging').update(payload).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('staging').delete().eq('id', id);
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
    await _client.from('shipped').update(payload).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('shipped').delete().eq('id', id);
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

  /// Legacy Order History lookup: all changelog actions containing this SO,
  /// newest first. This is intentionally read-only and available through RLS
  /// to the same anonymous users who can read staging and shipped records.
  Future<List<ChangelogEntry>> forOrder(String so) async {
    final rows = await _client
        .from('changelog')
        .select()
        .ilike('action', '%$so%')
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
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );
    return path;
  }
}

class NotifyRepository {
  NotifyRepository(this._client);
  final SupabaseClient _client;

  Future<void> sendPmNotification(Map<String, dynamic> payload) async {
    final res = await _client.functions.invoke('notify-pm', body: payload);
    if (res.status >= 400) {
      throw Exception('Notification failed (${res.status}): ${res.data}');
    }
  }
}
