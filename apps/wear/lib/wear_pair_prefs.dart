import 'package:shared_preferences/shared_preferences.dart';

/// Local Wear pairing flag for floor (anon) codes that do not mint a session.
abstract final class WearPairPrefs {
  static const pairedKey = 'wear_floor_paired';

  static Future<bool> isPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pairedKey) ?? false;
  }

  static Future<void> setPaired(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pairedKey, value);
  }
}
