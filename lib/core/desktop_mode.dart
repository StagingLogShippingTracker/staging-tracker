import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _desktopModeChannel = MethodChannel('swift_staging_log/desktop_mode');

/// True on Windows/macOS/Linux. On Android, true only in desktop/DeX mode
/// (UI_MODE_TYPE_DESK or Samsung SEM desktop flags) — not plain tablet.
final desktopModeProvider =
    StateNotifierProvider<DesktopModeNotifier, bool>((ref) {
  return DesktopModeNotifier();
});

class DesktopModeNotifier extends StateNotifier<bool>
    with WidgetsBindingObserver {
  DesktopModeNotifier() : super(_nativeDesktopDefault) {
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  static bool get _nativeDesktopDefault {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Whether F-key chrome should appear in the command dock / shortcut UI.
  static bool showHotkeyLabels(bool desktopMode) {
    if (kIsWeb) return false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }
    if (Platform.isAndroid) return desktopMode;
    return false;
  }

  Future<void> _refresh() async {
    if (kIsWeb || !Platform.isAndroid) {
      state = _nativeDesktopDefault;
      return;
    }
    try {
      final value = await _desktopModeChannel.invokeMethod<bool>(
        'isDesktopMode',
      );
      if (!mounted) return;
      state = value ?? false;
    } catch (_) {
      if (!mounted) return;
      // Channel missing or failed — treat as touch Android (no F-keys).
      state = false;
    }
  }

  @override
  void didChangeMetrics() {
    _refresh();
  }

  @override
  void didChangePlatformBrightness() {
    // Some OEMs reshuffle uiMode alongside theme; re-check cheaply.
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
