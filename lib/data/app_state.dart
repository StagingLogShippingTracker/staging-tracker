import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import '../domain/location_intelligence.dart';
import '../domain/status.dart';
import 'supabase_repositories.dart';

typedef PhotoBytes = ({Uint8List bytes, String name});

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final stagingRepoProvider = Provider(
  (ref) => StagingRepository(ref.watch(supabaseClientProvider)),
);
final shippedRepoProvider = Provider(
  (ref) => ShippedRepository(ref.watch(supabaseClientProvider)),
);
final changelogRepoProvider = Provider(
  (ref) => ChangelogRepository(ref.watch(supabaseClientProvider)),
);
final rosterRepoProvider = Provider(
  (ref) => RosterRepository(ref.watch(supabaseClientProvider)),
);
final photoStorageProvider = Provider(
  (ref) => PhotoStorage(ref.watch(supabaseClientProvider)),
);
final notifyRepoProvider = Provider(
  (ref) => NotifyRepository(ref.watch(supabaseClientProvider)),
);

final contactsProvider = FutureProvider<List<ContactPerson>>((ref) async {
  final raw = await rootBundle.loadString('assets/contacts.json');
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => ContactPerson.fromMap(Map<String, dynamic>.from(e as Map)))
      .toList();
});

class AppData {
  const AppData({
    this.staging = const [],
    this.shipped = const [],
    this.loading = false,
    this.error,
  });

  final List<StagingEntry> staging;
  final List<ShippedEntry> shipped;
  final bool loading;
  final String? error;

  AppData copyWith({
    List<StagingEntry>? staging,
    List<ShippedEntry>? shipped,
    bool? loading,
    String? error,
  }) {
    return AppData(
      staging: staging ?? this.staging,
      shipped: shipped ?? this.shipped,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  int get orderCount =>
      {...staging.map((e) => e.so), ...shipped.map((e) => e.so)}.length;

  Map<String, int> get containerTotals {
    var skids = 0, boxes = 0, crates = 0, pipe = 0, other = 0;
    for (final e in staging) {
      // Type labels look like "2 Skids, 1 Box"; parse the count per segment
      // so mixed entries don't over-count every category with the full qty.
      for (final part in e.type.split(',')) {
        final seg = part.trim().toLowerCase();
        if (seg.isEmpty) continue;
        final n = int.tryParse(RegExp(r'^\d+').stringMatch(seg) ?? '') ?? 1;
        if (seg.contains('skid')) {
          skids += n;
        } else if (seg.contains('box')) {
          boxes += n;
        } else if (seg.contains('crate')) {
          crates += n;
        } else if (seg.contains('pipe') || seg.contains('rod')) {
          pipe += n;
        } else {
          other += n;
        }
      }
    }
    return {
      'orders': orderCount,
      'containers': staging.fold<int>(0, (sum, e) => sum + e.qty),
      'skids': skids,
      'boxes': boxes,
      'crates': crates,
      'pipe': pipe,
      'other': other,
      'shipped': shipped.length,
      'staging': staging.length,
    };
  }
}

class AppDataNotifier extends StateNotifier<AppData> {
  AppDataNotifier(this._ref, {bool initialize = true})
    : super(AppData(loading: initialize)) {
    if (initialize) {
      refresh();
      _bindRealtime();
    }
  }

  final Ref _ref;
  RealtimeChannel? _channel;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final staging = await _ref.read(stagingRepoProvider).fetchAll();
      final shipped = await _ref.read(shippedRepoProvider).fetchAll();
      state = AppData(staging: staging, shipped: shipped);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void _bindRealtime() {
    final client = _ref.read(supabaseClientProvider);
    _channel = client
        .channel('slst-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'staging',
          callback: (_) => refresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shipped',
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final appDataProvider = StateNotifierProvider<AppDataNotifier, AppData>(
  (ref) => AppDataNotifier(ref),
);

class LocalPrefs {
  LocalPrefs(this._prefs);
  final SharedPreferences _prefs;

  bool get darkMode => _prefs.getBool('swift_theme_dark') ?? false;
  Future<void> setDarkMode(bool v) => _prefs.setBool('swift_theme_dark', v);

  List<String> get hiddenMemory =>
      _prefs.getStringList('swift_hidden_memory') ?? const [];

  Future<void> hideMemory(String value) async {
    final next = {...hiddenMemory, value}.toList();
    await _prefs.setStringList('swift_hidden_memory', next);
  }

  Set<String> get overdueHandled =>
      (_prefs.getStringList('swift_overdue_handled') ?? const []).toSet();

  Future<void> markOverdueHandled(String id) async {
    final next = {...overdueHandled, id}.toList();
    await _prefs.setStringList('swift_overdue_handled', next);
  }

  // Staging verification audit (legacy web key names kept for parity).

  String? get reportState => _prefs.getString('swift_report_state');
  Future<void> setReportState(String json) =>
      _prefs.setString('swift_report_state', json);
  Future<void> clearReportState() => _prefs.remove('swift_report_state');

  List<String> get discrepancyIds =>
      _prefs.getStringList('swift_discrepancies') ?? const [];
  Future<void> setDiscrepancyIds(List<String> ids) =>
      _prefs.setStringList('swift_discrepancies', ids);
}

final prefsProvider = FutureProvider<LocalPrefs>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LocalPrefs(prefs);
});

const carrierRosterType = 'carrier';
const customerRosterType = 'customer';
const personRosterType = 'person_by';

List<String> filterCarrierSuggestions(
  Iterable<String> values, {
  Iterable<String> hidden = const [],
}) {
  return filterRememberedValues(values, hidden: hidden);
}

final carrierSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final values = await ref
      .watch(rosterRepoProvider)
      .valuesFor(carrierRosterType);
  final prefs = await ref.watch(prefsProvider.future);
  return filterCarrierSuggestions(values, hidden: prefs.hiddenMemory);
});

final personSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final values = await ref
      .watch(rosterRepoProvider)
      .valuesFor(personRosterType);
  final prefs = await ref.watch(prefsProvider.future);
  return filterRememberedValues(values, hidden: prefs.hiddenMemory);
});

final customerSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final roster = await ref
      .watch(rosterRepoProvider)
      .valuesFor(customerRosterType);
  final data = ref.watch(appDataProvider);
  final prefs = await ref.watch(prefsProvider.future);
  return filterRememberedValues([
    ...roster,
    ...data.staging.map((entry) => entry.customer),
    ...data.shipped.map((entry) => entry.customer),
  ], hidden: prefs.hiddenMemory);
});

final locationSuggestionsProvider =
    FutureProvider.family<List<String>, LocationCategory>((
      ref,
      category,
    ) async {
      final roster = await ref
          .watch(rosterRepoProvider)
          .valuesFor(category.rosterType);
      final data = ref.watch(appDataProvider);
      final prefs = await ref.watch(prefsProvider.future);
      final fromRecords = [
        ...data.staging.map((entry) => entry.location),
        ...data.shipped.map((entry) => entry.location),
      ].where((value) => classifyLocation(value) == category);
      return filterRememberedValues([
        ...roster,
        ...fromRecords,
      ], hidden: prefs.hiddenMemory);
    });

final recentBinMovementsProvider = FutureProvider<List<ChangelogEntry>>((
  ref,
) async {
  final rows = await ref.watch(changelogRepoProvider).recent(limit: 150);
  return rows
      .where(
        (entry) =>
            entry.action.trimLeft().toLowerCase().startsWith('bin movement:'),
      )
      .toList();
});

final darkModeProvider = StateProvider<bool>((ref) => false);

class OperationsService {
  OperationsService(this._ref);
  final Ref _ref;

  StagingRepository get _staging => _ref.read(stagingRepoProvider);
  ShippedRepository get _shipped => _ref.read(shippedRepoProvider);
  ChangelogRepository get _log => _ref.read(changelogRepoProvider);
  RosterRepository get _roster => _ref.read(rosterRepoProvider);
  PhotoStorage get _photos => _ref.read(photoStorageProvider);
  NotifyRepository get _notify => _ref.read(notifyRepoProvider);

  Future<bool> soConflict(String so, {String? ignoreId}) async {
    final data = _ref.read(appDataProvider);
    return data.staging.any(
      (e) =>
          e.so.trim().toLowerCase() == so.trim().toLowerCase() &&
          e.id != ignoreId,
    );
  }

  Future<void> createStaging({
    required String so,
    required String customer,
    required String location,
    required String statusUi,
    required ContainerCounts containers,
    String? weight,
    String? comments,
    String? stagedBy,
    String? futureDateYmd,
    List<PhotoBytes> photos = const [],
    bool allowExistingSo = false,
    LocationCategory? locationCategory,
  }) async {
    if (containers.total <= 0) {
      throw Exception('At least one container is required.');
    }
    if (!allowExistingSo && await soConflict(so)) {
      throw Exception('SO $so already exists in Staging.');
    }
    final paths = <String>[];
    for (final p in photos) {
      paths.add(await _photos.uploadBytes(bytes: p.bytes, fileName: p.name));
    }
    final status = StatusRules.toDb(statusUi, futureDateYmd: futureDateYmd);
    await _staging.insert({
      'so': so.trim(),
      'customer': customer.trim(),
      'location': location.trim(),
      'status': status,
      'type': containers.typeLabel,
      'qty': containers.total,
      'weight': weight?.trim(),
      'comments': comments?.trim(),
      'staged_by': stagedBy?.trim(),
      'photo_urls': paths,
    });
    await _rememberEntryValues(
      customer: customer,
      person: stagedBy,
      location: location,
      locationCategory: locationCategory,
    );
    await _log.log('staging', 'Added new entry for SO: ${so.trim()}');
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> shipEntry({
    required StagingEntry entry,
    required String carrier,
    required String shippedBy,
    String? pmEmail,
    bool notifyPm = false,
    List<PhotoBytes> extraPhotos = const [],
  }) async {
    final paths = [...entry.photoUrls];
    for (final p in extraPhotos) {
      paths.add(await _photos.uploadBytes(bytes: p.bytes, fileName: p.name));
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
    await _rememberEntryValues(
      customer: entry.customer,
      person: shippedBy,
      location: entry.location,
    );
    await _rememberCarrier(carrier);
    await _log.log('staging', 'Ship Confirmed SO: ${entry.so}');
    await _log.log('shipped', 'Added via Ship Confirm: SO: ${entry.so}');
    await _log.log(
      'staging',
      'Bin Movement: To Shipped Log — SO ${entry.so}: ${entry.type} moved from Staging Log to Shipped Log (${entry.location})',
    );

    if (notifyPm && pmEmail != null && pmEmail.contains('@')) {
      await _notify.sendPmNotification({
        'to': pmEmail,
        'cc': 'warehouse1@swiftsupply.ca',
        'subject': 'SHIPPED: SO ${entry.so} - ${entry.customer}',
        'body':
            'Your order has shipped.<br><br><b>SO#</b> | ${entry.so}<br><b>Customer</b> | ${entry.customer}<br><b>Carrier</b> | ${carrier.trim()}<br><b>Containers</b> | ${entry.type}<br><b>Shipped By</b> | ${shippedBy.trim()}',
        'attachments': paths,
        'notification_type': 'ship_confirm',
      });
    }
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> quickShip({
    required String so,
    required String customer,
    required String carrier,
    required String shippedBy,
    required ContainerCounts containers,
    String? location,
    String? weight,
    String? comments,
    String? pmEmail,
    bool notifyPm = false,
    List<PhotoBytes> photos = const [],
    LocationCategory? locationCategory,
  }) async {
    final paths = <String>[];
    for (final p in photos) {
      paths.add(await _photos.uploadBytes(bytes: p.bytes, fileName: p.name));
    }
    await _shipped.insert({
      'so': so.trim(),
      'customer': customer.trim(),
      'type': containers.typeLabel,
      'qty': containers.total,
      'carrier': carrier.trim(),
      'location': location?.trim() ?? '',
      'weight': weight?.trim(),
      'comments': comments?.trim(),
      'shipped_by': shippedBy.trim(),
      'pmd_email': _pmDisplay(pmEmail),
      'photo_urls': paths,
    });
    await _rememberCarrier(carrier);
    await _rememberEntryValues(
      customer: customer,
      person: shippedBy,
      location: location,
      locationCategory: locationCategory,
    );
    await _log.log('shipped', 'Added via Quick Ship: SO: ${so.trim()}');
    if (notifyPm && pmEmail != null && pmEmail.contains('@')) {
      await _notify.sendPmNotification({
        'to': pmEmail,
        'cc': 'warehouse1@swiftsupply.ca',
        'subject': 'SHIPPED: SO ${so.trim()} - ${customer.trim()}',
        'body':
            'Your order has shipped (Quick Ship).<br><br><b>SO#</b> | ${so.trim()}<br><b>Customer</b> | ${customer.trim()}<br><b>Carrier</b> | ${carrier.trim()}',
        'attachments': paths,
        'notification_type': 'quick_ship',
      });
    }
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> returnToStock({
    required StagingEntry entry,
    required String pickedBy,
    required String returnedBy,
    required String reason,
    String? pmEmail,
    bool notifyPm = false,
  }) async {
    await _shipped.insert({
      'so': entry.so,
      'customer': entry.customer,
      'type': entry.type,
      'qty': entry.qty,
      'carrier': 'RETURNED TO STOCK',
      'location': entry.location,
      'weight': entry.weight,
      'comments': entry.comments,
      'shipped_by': returnedBy.trim(),
      'pmd_email': _pmDisplay(pmEmail) ?? pickedBy.trim(),
      'photo_urls': entry.photoUrls,
    });
    await _staging.delete(entry.id);
    await _rememberEntryValues(
      customer: entry.customer,
      people: [pickedBy, returnedBy],
      location: entry.location,
    );
    await _log.log('staging', 'Returned to Stock SO: ${entry.so}');
    await _log.log('shipped', 'Added Return to Stock log for SO: ${entry.so}');
    if (notifyPm && pmEmail != null && pmEmail.contains('@')) {
      await _notify.sendPmNotification({
        'to': pmEmail,
        'cc': 'warehouse1@swiftsupply.ca',
        'subject': 'RETURN TO STOCK: SO ${entry.so} - ${entry.customer}',
        'body':
            'Returned to Stock.<br><br><b>Reason</b> | $reason<br><b>SO#</b> | ${entry.so}<br><b>Picked By</b> | $pickedBy<br><b>Returned By</b> | $returnedBy',
        'attachments': entry.photoUrls,
        'notification_type': 'return_to_stock',
      });
    }
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> undoShipment(ShippedEntry entry) async {
    if (await soConflict(entry.so)) {
      throw Exception('Cannot undo: SO ${entry.so} already exists in Staging.');
    }
    await _staging.insert({
      'so': entry.so,
      'customer': entry.customer,
      'type': entry.type,
      'qty': entry.qty,
      'location': entry.location,
      'weight': entry.weight,
      'comments': entry.comments,
      'status': 'Partial',
      'photo_urls': entry.photoUrls,
    });
    await _shipped.delete(entry.id);
    await _log.log('shipped', 'Undo Shipment Action for SO: ${entry.so}');
    await _log.log(
      'staging',
      'Restored to Staging via Undo for SO: ${entry.so}',
    );
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> deleteRecord({
    required String table,
    required String id,
    required String so,
  }) async {
    if (table == 'staging') {
      await _staging.delete(id);
    } else {
      await _shipped.delete(id);
    }
    await _log.log(table, 'Deleted entry for SO: $so');
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> updateStaging(
    String id,
    Map<String, dynamic> payload, {
    LocationCategory? locationCategory,
  }) async {
    StagingEntry? previous;
    for (final entry in _ref.read(appDataProvider).staging) {
      if (entry.id == id) {
        previous = entry;
        break;
      }
    }
    await _staging.update(id, payload);
    await _rememberEntryValues(
      customer: payload['customer']?.toString(),
      person: payload['staged_by']?.toString(),
      location: payload['location']?.toString(),
      locationCategory: locationCategory,
    );
    await _log.log('staging', 'Edited SO ${payload['so'] ?? id}');
    final nextLocation = payload['location']?.toString().trim();
    if (previous != null &&
        nextLocation != null &&
        locationKey(previous.location) != locationKey(nextLocation)) {
      await _log.log(
        'staging',
        'Bin Movement: Relocated — SO ${payload['so'] ?? previous.so} moved from ${previous.location.isEmpty ? 'Unknown' : previous.location} to $nextLocation',
      );
    }
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> updateStagingWithPhotos(
    StagingEntry entry,
    Map<String, dynamic> payload,
    List<PhotoBytes> photos, {
    LocationCategory? locationCategory,
  }) async {
    final paths = [...entry.photoUrls];
    for (final photo in photos) {
      paths.add(
        await _photos.uploadBytes(bytes: photo.bytes, fileName: photo.name),
      );
    }
    await updateStaging(entry.id, {
      ...payload,
      'photo_urls': paths,
    }, locationCategory: locationCategory);
  }

  Future<void> updateShipped(String id, Map<String, dynamic> payload) async {
    await _shipped.update(id, payload);
    final carrier = payload['carrier']?.toString();
    if (carrier != null) await _rememberCarrier(carrier);
    await _rememberEntryValues(
      customer: payload['customer']?.toString(),
      person: payload['shipped_by']?.toString(),
      location: payload['location']?.toString(),
    );
    await _log.log('shipped', 'Edited SO ${payload['so'] ?? id}');
    await _ref.read(appDataProvider.notifier).refresh();
  }

  /// Split one staging row into two rows that share the same SO metadata.
  Future<void> splitStaging({
    required StagingEntry entry,
    required ContainerCounts first,
    required ContainerCounts second,
  }) async {
    if (first.total <= 0 || second.total <= 0) {
      throw Exception('Both split parts need at least one container.');
    }
    await _staging.update(entry.id, {
      'type': first.typeLabel,
      'qty': first.total,
    });
    await _staging.insert({
      'so': entry.so,
      'customer': entry.customer,
      'location': entry.location,
      'status': entry.status,
      'type': second.typeLabel,
      'qty': second.total,
      'weight': entry.weight,
      'comments': entry.comments,
      'staged_by': entry.stagedBy,
      'photo_urls': entry.photoUrls,
    });
    await _log.log('staging', 'Split SO ${entry.so} into two staging rows');
    await _ref.read(appDataProvider.notifier).refresh();
  }

  /// Consolidate multiple same-SO staging rows into the first selected row.
  Future<void> consolidateStaging(List<StagingEntry> entries) async {
    if (entries.length < 2) {
      throw Exception('Select at least two staging rows to consolidate.');
    }
    final so = entries.first.so.trim().toLowerCase();
    if (!entries.every((e) => e.so.trim().toLowerCase() == so)) {
      throw Exception('Consolidate requires the same SO on every row.');
    }
    final keep = entries.first;
    var skids = 0, boxes = 0, crates = 0, pipe = 0, other = 0;
    final photos = <String>{...keep.photoUrls};
    for (final e in entries) {
      final parsed = ContainerCounts.parse(e.type);
      skids += parsed.skids;
      boxes += parsed.boxes;
      crates += parsed.crates;
      pipe += parsed.pipe;
      other += parsed.other;
      photos.addAll(e.photoUrls);
    }
    // Fallback when type labels are mixed: keep summed qty under a combined label.
    final counts = ContainerCounts(
      skids: skids,
      boxes: boxes,
      crates: crates,
      pipe: pipe,
      other: other,
    );
    final type = counts.total > 0
        ? counts.typeLabel
        : entries.map((e) => e.type).join(' + ');
    final qty = counts.total > 0
        ? counts.total
        : entries.fold<int>(0, (sum, e) => sum + e.qty);
    await _staging.update(keep.id, {
      'type': type,
      'qty': qty,
      'photo_urls': photos.toList(),
    });
    for (final e in entries.skip(1)) {
      await _staging.delete(e.id);
    }
    await _log.log(
      'staging',
      'Consolidated ${entries.length} rows for SO ${keep.so}',
    );
    await _ref.read(appDataProvider.notifier).refresh();
  }

  Future<void> sendPoNotification({
    required String po,
    required String customer,
    required String pmEmail,
    String? linkedSo,
    String? details,
    List<PhotoBytes> photos = const [],
  }) async {
    final paths = <String>[];
    for (final p in photos) {
      paths.add(await _photos.uploadBytes(bytes: p.bytes, fileName: p.name));
    }
    await _notify.sendPmNotification({
      'to': pmEmail,
      'cc': 'warehouse1@swiftsupply.ca',
      'subject':
          'PO Notification: $po${linkedSo == null ? '' : ' (SO $linkedSo)'}',
      'body':
          'PO Notification<br><br><b>PO#</b> | $po<br><b>Customer</b> | $customer${linkedSo == null ? '' : '<br><b>SO#</b> | $linkedSo'}${details == null || details.isEmpty ? '' : '<br><br>$details'}',
      'attachments': paths,
      'notification_type': 'po_notification',
    });
    await _rememberEntryValues(customer: customer);
    await _log.log(
      'staging',
      'Sent Automated PO Notification for PO: $po${linkedSo == null ? '' : ' (SO $linkedSo)'} (PM: $pmEmail)',
    );
  }

  Future<void> sendReturnNotification({
    required String so,
    required String customer,
    required String pmEmail,
    String? details,
    List<PhotoBytes> photos = const [],
  }) async {
    final paths = <String>[];
    for (final p in photos) {
      paths.add(await _photos.uploadBytes(bytes: p.bytes, fileName: p.name));
    }
    await _notify.sendPmNotification({
      'to': pmEmail,
      'cc': 'warehouse1@swiftsupply.ca',
      'subject': 'Return Notification: SO $so - $customer',
      'body':
          'Return Notification<br><br><b>SO#</b> | $so<br><b>Customer</b> | $customer${details == null || details.isEmpty ? '' : '<br><br>$details'}',
      'attachments': paths,
      'notification_type': 'return_notification',
    });
    await _rememberEntryValues(customer: customer);
    await _log.log('staging', 'Sent Automated Return Notification for SO: $so');
  }

  String? _pmDisplay(String? email) {
    if (email == null || email.isEmpty) return null;
    if (!email.contains('@')) return email;
    final local = email.split('@').first.split('.').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  Future<void> _rememberCarrier(String raw) async {
    final prefs = await _ref.read(prefsProvider.future);
    final values = filterCarrierSuggestions([raw], hidden: prefs.hiddenMemory);
    if (values.isEmpty) return;
    await _roster.remember(carrierRosterType, values.single);
    _ref.invalidate(carrierSuggestionsProvider);
  }

  Future<void> _rememberEntryValues({
    String? customer,
    String? person,
    Iterable<String> people = const [],
    String? location,
    LocationCategory? locationCategory,
  }) async {
    final prefs = await _ref.read(prefsProvider.future);
    Future<void> remember(String type, String? raw) async {
      if (raw == null) return;
      final values = filterRememberedValues([raw], hidden: prefs.hiddenMemory);
      if (values.isEmpty) return;
      try {
        await _roster.remember(type, values.single);
      } catch (_) {
        // The primary record has already saved. Roster memory is best effort
        // and must never make a successful operation appear to have failed.
      }
    }

    await remember(customerRosterType, customer);
    await remember(personRosterType, person);
    for (final value in people) {
      await remember(personRosterType, value);
    }
    if (location != null && location.trim().isNotEmpty) {
      final category = locationCategory ?? classifyLocation(location);
      await remember(category.rosterType, location);
    }
    _ref.invalidate(customerSuggestionsProvider);
    _ref.invalidate(personSuggestionsProvider);
    for (final category in LocationCategory.values) {
      _ref.invalidate(locationSuggestionsProvider(category));
    }
  }
}

final operationsProvider = Provider((ref) => OperationsService(ref));
