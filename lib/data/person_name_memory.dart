import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contact_sync.dart';
import 'remembered_contacts.dart';

class PersonNameMemoryState {
  const PersonNameMemoryState({
    this.names = const [],
    this.loading = false,
    this.error,
  });

  final List<String> names;
  final bool loading;
  final String? error;

  Set<String> get rememberedKeys => {
        for (final n in names) n.trim().toLowerCase(),
      };

  PersonNameMemoryState copyWith({
    List<String>? names,
    bool? loading,
    Object? error = _unset,
  }) {
    return PersonNameMemoryState(
      names: names ?? this.names,
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

const _unset = Object();

class PersonNameMemory extends StateNotifier<PersonNameMemoryState> {
  PersonNameMemory()
      : _store = RememberedContactsStore(),
        super(const PersonNameMemoryState(loading: true)) {
    _sync = ContactSync(_store);
    _boot();
  }

  final RememberedContactsStore _store;
  late final ContactSync _sync;
  Future<void>? _inFlight;

  Future<void> _boot() async {
    await _store.load();
    state = PersonNameMemoryState(names: List.of(_store.names));
    await sync();
  }

  Future<void> sync({
    bool forceRefresh = false,
    Iterable<String> seedNames = const [],
  }) async {
    while (_inFlight != null) {
      await _inFlight;
    }
    final gate = Completer<void>();
    _inFlight = gate.future;
    state = state.copyWith(loading: true, error: null);
    try {
      await _sync.syncOnLaunch(seedNames: seedNames);
      state = PersonNameMemoryState(names: List.of(_store.names));
    } on ContactSyncException catch (e) {
      state = PersonNameMemoryState(
        names: List.of(_store.names),
        error: e.message,
      );
    } catch (e) {
      state = PersonNameMemoryState(
        names: List.of(_store.names),
        error: '$e',
      );
    } finally {
      gate.complete();
      _inFlight = null;
    }
  }

  Future<void> remember(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    try {
      await _sync.remember(name);
    } on ContactSyncException {
      await _store.remember(name);
    } catch (_) {
      await _store.remember(name);
    }
    state = PersonNameMemoryState(names: List.of(_store.names));
  }

  /// Returns a user-facing snack message, or null if nothing changed.
  Future<String?> forget(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return null;
    var removed = false;
    String? cloudError;
    try {
      removed = await _sync.forget(name);
    } on ContactSyncException catch (e) {
      removed = await _store.forget(name);
      cloudError = e.message;
    } catch (_) {
      removed = await _store.forget(name);
    }
    state = PersonNameMemoryState(names: List.of(_store.names));
    if (!removed) return null;
    if (cloudError != null) {
      return 'Removed locally; cloud sync failed: $cloudError';
    }
    return 'Removed “$name” from shared memory.';
  }
}

final personNameMemoryProvider =
    StateNotifierProvider<PersonNameMemory, PersonNameMemoryState>(
  (ref) => PersonNameMemory(),
);
