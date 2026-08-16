import 'package:supabase_flutter/supabase_flutter.dart';

import 'audit_order.dart';

class VerificationAuditState {
  const VerificationAuditState({
    required this.mode,
    required this.queue,
    required this.index,
    required this.results,
    required this.discrepancyIds,
    this.updatedAt,
  });

  final AuditMode mode;
  final List<String> queue;
  final int index;
  final List<Map<String, String>> results;
  final List<String> discrepancyIds;
  final DateTime? updatedAt;

  bool get isActive => queue.isNotEmpty && index < queue.length;

  Map<String, dynamic> toMap() => {
        'mode': auditModeName(mode),
        'queue': queue,
        'index': index,
        'results': results,
        'discrepancy_ids': discrepancyIds,
      };

  factory VerificationAuditState.fromMap(Map<String, dynamic> m) {
    return VerificationAuditState(
      mode: auditModeFromName('${m['mode'] ?? m['filter'] ?? 'all'}'),
      queue: (m['queue'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      index: (m['index'] as num?)?.toInt() ?? 0,
      results: [
        for (final r in (m['results'] as List? ?? const []))
          Map<String, String>.from(
            (r as Map).map((k, v) => MapEntry('$k', '$v')),
          ),
      ],
      discrepancyIds: (m['discrepancy_ids'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      updatedAt: m['updated_at'] == null
          ? null
          : DateTime.tryParse('${m['updated_at']}'),
    );
  }
}

class AuditStateRepository {
  AuditStateRepository(this._client);
  final SupabaseClient _client;

  Future<VerificationAuditState?> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('verification_audit_state')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return VerificationAuditState.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> upsertMine(VerificationAuditState state) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    await _client.from('verification_audit_state').upsert({
      'user_id': uid,
      ...state.toMap(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> clearMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('verification_audit_state').delete().eq('user_id', uid);
  }
}
