import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class StaleRecordException implements Exception {
  StaleRecordException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transactional inventory RPCs shared by Windows / Android / Wear.
class InventoryRpc {
  InventoryRpc(this._client);
  final SupabaseClient _client;

  void _requireAuth() {
    if (_client.auth.currentUser == null) {
      throw StaleRecordException('Sign in required. Your session may have expired.');
    }
  }

  Future<ShippedEntry> shipStagingEntry({
    required String stagingId,
    required String carrier,
    required String shippedBy,
    String? type,
    int? qty,
    String? weight,
    List<String>? photoUrls,
    String? pmdEmail,
    String notificationStatus = 'none',
  }) async {
    _requireAuth();
    try {
      final raw = await _client.rpc(
        'ship_staging_entry',
        params: {
          'p_staging_id': stagingId,
          'p_carrier': carrier,
          'p_shipped_by': shippedBy,
          'p_type': type,
          'p_qty': qty,
          'p_weight': weight,
          'p_photo_urls': photoUrls,
          'p_pmd_email': pmdEmail,
          'p_notification_status': notificationStatus,
        },
      );
      return ShippedEntry.fromMap(Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }

  Future<ShippedEntry> returnStagingToStock({
    required String stagingId,
    required String pickedBy,
    required String returnedBy,
    required String reason,
    List<String>? photoUrls,
    String? pmdEmail,
    String notificationStatus = 'none',
  }) async {
    _requireAuth();
    try {
      final raw = await _client.rpc(
        'return_staging_to_stock',
        params: {
          'p_staging_id': stagingId,
          'p_picked_by': pickedBy,
          'p_returned_by': returnedBy,
          'p_reason': reason,
          'p_photo_urls': photoUrls,
          'p_pmd_email': pmdEmail,
          'p_notification_status': notificationStatus,
        },
      );
      return ShippedEntry.fromMap(Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }

  Future<StagingEntry> undoShipment({
    required String shippedId,
    bool allowExistingSo = false,
  }) async {
    _requireAuth();
    try {
      final raw = await _client.rpc(
        'undo_shipment',
        params: {
          'p_shipped_id': shippedId,
          'p_allow_existing_so': allowExistingSo,
        },
      );
      return StagingEntry.fromMap(Map<String, dynamic>.from(raw as Map));
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }

  Future<void> splitStaging({
    required String stagingId,
    required String firstType,
    required int firstQty,
    required String secondType,
    required int secondQty,
  }) async {
    _requireAuth();
    try {
      await _client.rpc(
        'split_staging',
        params: {
          'p_staging_id': stagingId,
          'p_first_type': firstType,
          'p_first_qty': firstQty,
          'p_second_type': secondType,
          'p_second_qty': secondQty,
        },
      );
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }

  Future<ConsolidateResult> consolidateStaging({
    required List<String> sourceIds,
    required String type,
    required int qty,
    List<String>? photoUrls,
  }) async {
    _requireAuth();
    try {
      final raw = await _client.rpc(
        'consolidate_staging',
        params: {
          'p_source_ids': sourceIds,
          'p_type': type,
          'p_qty': qty,
          'p_photo_urls': photoUrls,
        },
      );
      final map = Map<String, dynamic>.from(raw as Map);
      return ConsolidateResult(
        merged: StagingEntry.fromMap(
          Map<String, dynamic>.from(map['merged'] as Map),
        ),
        undoId: '${map['undo_id']}',
        expiresAt: DateTime.tryParse('${map['expires_at']}') ??
            DateTime.now().add(const Duration(minutes: 2)),
      );
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }

  Future<void> reverseConsolidation(String undoId) async {
    _requireAuth();
    try {
      await _client.rpc(
        'reverse_consolidation',
        params: {'p_undo_id': undoId},
      );
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }

  Future<void> updateShippedNotificationStatus({
    required String shippedId,
    required String status,
    String? error,
  }) async {
    _requireAuth();
    try {
      await _client.rpc(
        'update_shipped_notification_status',
        params: {
          'p_shipped_id': shippedId,
          'p_status': status,
          'p_error': error,
        },
      );
    } on PostgrestException catch (e) {
      throw StaleRecordException(e.message);
    }
  }
}

class ConsolidateResult {
  const ConsolidateResult({
    required this.merged,
    required this.undoId,
    required this.expiresAt,
  });

  final StagingEntry merged;
  final String undoId;
  final DateTime expiresAt;
}
