import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal CRUD for a simple cross-app "remembered name" directory: a
/// values table plus a tombstones table, both keyed by a lowercased
/// `name_key`. [SharedContactsClient] and [SharedCarriersClient] are thin,
/// table-name-bound wrappers over this — the read/upsert/tombstone logic is
/// identical for any such directory.
class _SharedNameDirectory {
  const _SharedNameDirectory(
    this._client, {
    required this.table,
    required this.tombstoneTable,
  });

  final SupabaseClient _client;
  final String table;
  final String tombstoneTable;

  static String nameKey(String raw) => raw.trim().toLowerCase();

  /// Remembered names, most-recently-used first, honoring tombstones written
  /// by any app's "forget" action.
  Future<List<String>> fetchNames({int limit = 60}) async {
    final tombstoned = await _fetchTombstoneKeys();
    final rows = await _client
        .from(table)
        .select('name_key, name, last_used_at')
        .order('last_used_at', ascending: false);
    final seen = <String>{};
    final out = <String>[];
    for (final raw in rows as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final key = '${m['name_key'] ?? ''}'.trim();
      final name = '${m['name'] ?? ''}'.trim();
      if (key.isEmpty || name.isEmpty) continue;
      if (tombstoned.contains(key)) continue;
      if (!seen.add(key)) continue;
      out.add(name);
      if (out.length >= limit) break;
    }
    return out;
  }

  Future<Set<String>> _fetchTombstoneKeys() async {
    final rows = await _client.from(tombstoneTable).select('name_key');
    return {
      for (final raw in rows as List)
        '${Map<String, dynamic>.from(raw as Map)['name_key'] ?? ''}'.trim(),
    }..removeWhere((k) => k.isEmpty);
  }

  /// Remembers a name into the shared directory (upsert; clears any prior
  /// tombstone so a re-typed name reappears everywhere it was forgotten).
  Future<void> remember(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    final key = nameKey(name);
    await _client.from(tombstoneTable).delete().eq('name_key', key);
    await _client.from(table).upsert(
      {
        'name_key': key,
        'name': name,
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'name_key',
    );
  }
}

/// Cross-app shared person-name directory (`shared_contacts` /
/// `shared_contact_tombstones`).
///
/// This is the same Supabase-backed directory used by:
///  - the Windows/Android app's "Staged By" / "Shipped By" / "Picked by" /
///    "Returned by" fields (via the richer local-cache + sync layer in
///    `lib/data/contact_sync.dart` and `personNameMemoryProvider`), and
///  - Swift Document Generator's "Swift Contact" field.
///
/// Wear uses this lean client directly (no local cache, no tombstone-delete
/// UI) so a name entered on any of the three surfaces shows up on the other
/// two — there is exactly one shared directory, not three separate ones.
class SharedContactsClient {
  SharedContactsClient(SupabaseClient client)
      : _directory = _SharedNameDirectory(
          client,
          table: 'shared_contacts',
          tombstoneTable: 'shared_contact_tombstones',
        );

  final _SharedNameDirectory _directory;

  static String nameKey(String raw) => _SharedNameDirectory.nameKey(raw);

  Future<List<String>> fetchNames({int limit = 60}) =>
      _directory.fetchNames(limit: limit);

  Future<void> remember(String raw) => _directory.remember(raw);
}

/// Cross-app shared carrier-name directory (`shared_carriers` /
/// `shared_carrier_tombstones`) — the same store behind this app's "Carrier"
/// field (Staging & Shipping Log, Windows/Android and Wear) and Swift
/// Document Generator's "Carrier" field.
class SharedCarriersClient {
  SharedCarriersClient(SupabaseClient client)
      : _directory = _SharedNameDirectory(
          client,
          table: 'shared_carriers',
          tombstoneTable: 'shared_carrier_tombstones',
        );

  final _SharedNameDirectory _directory;

  static String nameKey(String raw) => _SharedNameDirectory.nameKey(raw);

  Future<List<String>> fetchNames({int limit = 60}) =>
      _directory.fetchNames(limit: limit);

  Future<void> remember(String raw) => _directory.remember(raw);
}
