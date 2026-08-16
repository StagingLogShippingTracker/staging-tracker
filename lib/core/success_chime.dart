import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Legacy web `playSuccessChime`: 1046.50 Hz sine (high C), 0.5s decay.
///
/// Used after ship confirm / quick ship, and after a PM notification send.
Future<void> playSuccessChime() async {
  try {
    final player = AudioPlayer();
    await player.play(AssetSource('success_chime.wav'));
    player.onPlayerComplete.listen((_) {
      player.dispose();
    });
  } catch (e, st) {
    debugPrint('Success chime skipped: $e\n$st');
  }
}
