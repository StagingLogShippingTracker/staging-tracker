import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'formatters.dart';
import 'inventory_rpc.dart';
import 'models.dart';
import 'repositories.dart';
import 'validation.dart';

/// Shared ship-confirm path used by Wear (and available to phone/desktop).
class ShipOperations {
  ShipOperations(SupabaseClient client)
      : _staging = StagingRepository(client),
        _roster = RosterRepository(client),
        _photos = PhotoStorage(client),
        _notify = NotifyRepository(client),
        _rpc = InventoryRpc(client);

  final StagingRepository _staging;
  final RosterRepository _roster;
  final PhotoStorage _photos;
  final NotifyRepository _notify;
  final InventoryRpc _rpc;

  StagingRepository get staging => _staging;
  RosterRepository get roster => _roster;

  Future<List<StagingEntry>> fetchStaging() => _staging.fetchAll();

  Future<String?> shipEntry({
    required StagingEntry entry,
    required String carrier,
    required String shippedBy,
    String? pmEmail,
    bool notifyPm = false,
    List<PhotoBytes> extraPhotos = const [],
  }) async {
    SlstValidation.ensureShipFields(
      so: entry.so,
      customer: entry.customer,
      carrier: carrier,
      shippedBy: shippedBy,
    );
    final paths = [...entry.photoUrls];
    for (final p in extraPhotos) {
      paths.add(
        await _photos.uploadBytes(
          bytes: Uint8List.fromList(p.bytes),
          fileName: p.name,
        ),
      );
    }
    final pmName = _pmDisplay(pmEmail);
    final notifStatus =
        notifyPm && pmEmail != null && pmEmail.contains('@') ? 'pending' : 'none';
    final shipped = await _rpc.shipStagingEntry(
      stagingId: entry.id,
      carrier: carrier.trim(),
      shippedBy: shippedBy.trim(),
      photoUrls: paths,
      pmdEmail: pmName,
      notificationStatus: notifStatus,
    );
    try {
      await _roster.remember('carrier', carrier);
      await _roster.remember('person_by', shippedBy);
    } catch (_) {
      // Roster memory is best-effort; inventory already moved.
    }

    final shippedAt = formatShipNotificationTimestamp();
    return _notifyPmIfRequested(
      notifyPm: notifyPm,
      pmEmail: pmEmail,
      shippedId: shipped.id,
      payload: {
        'to': pmEmail,
        'cc': AppConfig.warehouseCc,
        'subject': 'SHIPPED: SO ${entry.so} - ${entry.customer}',
        'body':
            'Your order has shipped.<br><br><b>SO#</b> | ${entry.so}<br><b>Customer</b> | ${entry.customer}<br><b>Carrier</b> | ${carrier.trim()}<br><b>Containers</b> | ${entry.type}<br><b>Shipped By</b> | ${shippedBy.trim()}',
        'so': entry.so,
        'customer': entry.customer,
        'carrier': carrier.trim(),
        'shipped_at': shippedAt,
        'shipped_by': shippedBy.trim(),
        'containers': entry.type,
        'weight': entry.weight?.trim() ?? '',
        'comments': entry.comments?.trim() ?? '',
        'attachments': paths,
        'notification_type': 'ship_confirm',
        if (pmName != null && pmName.isNotEmpty) 'pm_name': pmName,
      },
    );
  }

  Future<String?> _notifyPmIfRequested({
    required bool notifyPm,
    required String? pmEmail,
    required String shippedId,
    required Map<String, dynamic> payload,
  }) async {
    if (!notifyPm) return null;
    if (pmEmail == null || !pmEmail.contains('@')) {
      await _rpc.updateShippedNotificationStatus(
        shippedId: shippedId,
        status: 'failed',
        error: 'No valid email',
      );
      return 'Saved, but PM was not notified (no valid email).';
    }
    try {
      await _notify.sendPmNotification(payload);
      await _rpc.updateShippedNotificationStatus(
        shippedId: shippedId,
        status: 'sent',
      );
      return null;
    } catch (e) {
      await _rpc.updateShippedNotificationStatus(
        shippedId: shippedId,
        status: 'failed',
        error: '$e',
      );
      return 'Saved, but PM notification failed: $e';
    }
  }

  String? _pmDisplay(String? email) {
    if (email == null || email.isEmpty) return null;
    if (!email.contains('@')) return email;
    final local = email.split('@').first.split('.').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }
}
