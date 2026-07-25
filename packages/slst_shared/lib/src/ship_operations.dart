import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';
import 'models.dart';
import 'repositories.dart';

final _shipEmailDateFmt = DateFormat('yyyy-MM-dd HH:mm');

/// Shared ship-confirm path used by Wear (and available to phone/desktop).
class ShipOperations {
  ShipOperations(SupabaseClient client)
      : _staging = StagingRepository(client),
        _shipped = ShippedRepository(client),
        _log = ChangelogRepository(client),
        _roster = RosterRepository(client),
        _photos = PhotoStorage(client),
        _notify = NotifyRepository(client);

  final StagingRepository _staging;
  final ShippedRepository _shipped;
  final ChangelogRepository _log;
  final RosterRepository _roster;
  final PhotoStorage _photos;
  final NotifyRepository _notify;

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
    await _shipped.insert({
      'so': entry.so,
      'customer': entry.customer,
      'type': entry.type,
      'qty': entry.qty,
      'carrier': carrier.trim(),
      'location': entry.location,
      'weight': entry.weight,
      'comments': entry.comments,
      'shipped_by': shippedBy.trim(),
      'pmd_email': pmName,
      'photo_urls': paths,
    });
    await _staging.delete(entry.id);
    await _roster.remember('carrier', carrier);
    await _roster.remember('person_by', shippedBy);
    await _log.log('staging', 'Ship Confirmed SO: ${entry.so}');
    await _log.log('shipped', 'Added via Ship Confirm: SO: ${entry.so}');
    await _log.log(
      'staging',
      'Bin Movement: To Shipped Log — SO ${entry.so}: ${entry.type} moved from Staging Log to Shipped Log (${entry.location})',
    );

    final shippedAt = _shipEmailDateFmt.format(DateTime.now());
    return _notifyPmIfRequested(
      notifyPm: notifyPm,
      pmEmail: pmEmail,
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
      },
    );
  }

  Future<String?> _notifyPmIfRequested({
    required bool notifyPm,
    required String? pmEmail,
    required Map<String, dynamic> payload,
  }) async {
    if (!notifyPm) return null;
    if (pmEmail == null || !pmEmail.contains('@')) {
      return 'Saved, but PM was not notified (no valid email).';
    }
    try {
      await _notify.sendPmNotification(payload);
      return null;
    } catch (e) {
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
