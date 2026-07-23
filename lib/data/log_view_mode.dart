import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogViewMode { list, card }

const _prefsKey = 'slst_log_view_mode';

/// Android defaults to cards; Windows (and other desktops) default to list.
LogViewMode defaultLogViewMode() {
  if (kIsWeb) return LogViewMode.list;
  try {
    if (Platform.isAndroid) return LogViewMode.card;
  } catch (_) {}
  return LogViewMode.list;
}

class LogViewModeNotifier extends StateNotifier<LogViewMode> {
  LogViewModeNotifier(this._prefs, LogViewMode initial) : super(initial);

  final SharedPreferences _prefs;

  Future<void> setMode(LogViewMode mode) async {
    state = mode;
    await _prefs.setString(_prefsKey, mode.name);
  }

  Future<void> toggle() => setMode(
        state == LogViewMode.list ? LogViewMode.card : LogViewMode.list,
      );
}

final logViewModeProvider =
    StateNotifierProvider<LogViewModeNotifier, LogViewMode>((ref) {
  throw UnimplementedError('logViewModeProvider must be overridden in main()');
});

Future<LogViewMode> loadLogViewMode(SharedPreferences prefs) async {
  final raw = prefs.getString(_prefsKey);
  if (raw == LogViewMode.card.name) return LogViewMode.card;
  if (raw == LogViewMode.list.name) return LogViewMode.list;
  return defaultLogViewMode();
}
