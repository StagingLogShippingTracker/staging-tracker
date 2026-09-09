import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swift_staging_shared/swift_staging_shared.dart';

import 'wear_pair_prefs.dart';

/// "Ready to show real content" signal for Wear's held native launch
/// screen (see `deferFirstFrame`/`allowFirstFrame` in `main.dart`) — mirrors
/// the phone app's `appDataReadyProvider`/Swift Document Generator's
/// `StartupSync`. Resolves once the floor-pairing check has settled and,
/// if already paired, the initial staging fetch has too — capped at 9s so
/// a slow/offline watch can never hold the launch screen open forever.
///
/// Wear keeps its own existing native launch screen (no new splash UI) —
/// this only gates *when* it goes away. [HomeScreen] still does its own
/// fetch on mount for its own realtime/refresh lifecycle; the small
/// redundant staging fetch this causes on launch is an accepted tradeoff
/// for not touching that already-working code path.
class WearStartup {
  WearStartup() {
    _ready = _run();
  }

  late final Future<void> _ready;
  Future<void> get ready => _ready;

  static const _timeout = Duration(seconds: 9);

  Future<void> _run() async {
    try {
      final paired = await WearPairPrefs.isPaired().timeout(_timeout);
      if (paired) {
        await ShipOperations(Supabase.instance.client)
            .fetchStaging()
            .timeout(_timeout);
      }
    } catch (_) {
      // Offline/slow, or not paired yet — proceed. _AuthGate and
      // HomeScreen own their own state and will retry/refresh normally.
    }
  }
}
