import 'package:shared_preferences/shared_preferences.dart';

/// Whether the rotatable wheel animates back to zero on release. When off,
/// the wheel holds its released angle and steering stays there until the
/// driver drags it back. Gyro steering ignores it.
class SpringBack {
  static const String prefsKey = 'wheeldeck.spring_back';
  static const bool fallback = true;

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? fallback;
  }

  static Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }
}
