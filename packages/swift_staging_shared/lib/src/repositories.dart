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

class NotificationLogRepository {
  NotificationLogRepository(this._client);
  final SupabaseClient _client;

  static const knownTypes = <String>[
    'ship_confirm',
    'quick_ship',
    'return_to_stock',
    'po_notification',
    'bulk_po_notification',
    'return_notification',
    'feedback',
    'feedback_notification',
  ];

  Future<List<NotificationLogEntry>> list([
    NotificationLogQuery query = const NotificationLogQuery(),
  ]) async {
    var from = query.from;
    var to = query.to;
    if (query.year != null) {
      final y = query.year!;
      final m = query.month;
      if (m != null) {
        from ??= DateTime(y, m, 1);
        to ??= DateTime(y, m + 1, 1);
      } else {
        from ??= DateTime(y, 1, 1);
        to ??= DateTime(y + 1, 1, 1);
      }
    }

    final sortCol = switch (query.sortBy) {
      NotificationLogSort.createdAt => 'created_at',
      NotificationLogSort.pmName => 'pm_name',
      NotificationLogSort.notificationType => 'notification_type',
      NotificationLogSort.status => 'status',
    };

    var q = _client.from('notification_log').select();
    if (from != null) {
      q = q.gte('created_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      q = q.lt('created_at', to.toUtc().toIso8601String());
    }
    final pm = query.pmName?.trim();
    if (pm != null && pm.isNotEmpty) {
      q = q.eq('pm_name', pm);
    }
    final type = query.notificationType?.trim();
    if (type != null && type.isNotEmpty) {
      q = q.eq('notification_type', type);
    }
    final status = query.status?.trim();
    if (status != null && status.isNotEmpty) {
      q = q.eq('status', status);
    }
    final channel = query.channel?.trim();
    if (channel != null && channel.isNotEmpty) {
      q = q.eq('channel', channel);
    }
    final rows = await q.order(sortCol, ascending: query.ascending).limit(
          query.limit,
        );
    var entries = (rows as List)
        .map(
          (e) =>
              NotificationLogEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    final search = query.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      entries = entries.where((e) {
        final hay =
            '${e.so ?? ''} ${e.po ?? ''} ${e.customer ?? ''} ${e.vendor ?? ''} '
            '${e.subject ?? ''} ${e.pmEmail ?? ''} ${e.pmName ?? ''}';
        return hay.toLowerCase().contains(search);
      }).toList();
    }
    return entries;
  }

  /// Distinct PM names present in the log (for filter dropdowns).
  Future<List<String>> distinctPmNames() async {
    final rows = await _client
        .from('notification_log')
        .select('pm_name')
        .not('pm_name', 'is', null)
        .order('pm_name')
        .limit(500);
    final names = <String>{};
    for (final row in rows as List) {
      final name = (row as Map)['pm_name']?.toString().trim() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

Future<List<ContactPerson>> loadBundledContacts() async {
  final raw = await rootBundle.loadString(
    'packages/swift_staging_shared/assets/contacts.json',
  );
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => ContactPerson.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
}
