import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kDarkModePrefsKey = 'slst.theme.dark';

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier(this._prefs, bool initial) : super(initial);

  final SharedPreferences _prefs;

  Future<void> setDark(bool dark) async {
    state = dark;
    await _prefs.setBool(kDarkModePrefsKey, dark);
  }

  Future<void> toggle() => setDark(!state);
}

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  throw UnimplementedError('darkModeProvider must be overridden in main()');
});

bool loadDarkMode(SharedPreferences prefs) {
  return prefs.getBool(kDarkModePrefsKey) ?? true;
}
