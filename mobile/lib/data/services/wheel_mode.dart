import 'package:shared_preferences/shared_preferences.dart';

import 'controller_preset.dart';

/// How steering input is captured on the phone.
enum WheelMode {
  /// Finger-drag circular wheel; N degrees of finger rotation = full lock.
  rotatable('rotatable', 'Rotatable'),

  /// Phone tilt via gyroscope.
  gyro('gyro', 'Gyro');

  const WheelMode(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static const String prefsKey = 'wheeldeck.wheel_mode';
  static const WheelMode fallback = rotatable;

  static WheelMode fromWireValue(String? v) => WheelMode.values
      .firstWhere((m) => m.wireValue == v, orElse: () => fallback);

  static Future<WheelMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}

/// Finger-rotation range mapping to full lock-to-lock, stored per game preset.
/// Gyro steering ignores degrees.
class RotationDegree {
  static const List<int> allowed = [180, 270, 900, 1080, 1800, 2520];
  static const int fallback = 900;

  static const String keyPrefix = 'wheeldeck.rotation_degree.';

  static String _key(GamePreset preset) => '$keyPrefix${preset.wireValue}';

  static Future<int> load(GamePreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_key(preset));
    if (stored == null || !allowed.contains(stored)) return fallback;
    return stored;
  }

  static Future<void> save(GamePreset preset, int degree) async {
    assert(allowed.contains(degree), 'Unsupported rotation degree: $degree');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(preset), degree);
  }
}
