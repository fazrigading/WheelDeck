import 'package:shared_preferences/shared_preferences.dart';

/// How dashboard buttons are interpreted by the desktop.
enum InputMapping {
  /// Dashboard controls become simulated keyboard presses (ETS2 defaults).
  keyboard('keyboard'),

  /// Dashboard controls become virtual-controller button presses.
  gamepad('gamepad');

  const InputMapping(this.wireValue);

  /// Value used in the `mapping` frame, shared with the desktop.
  final String wireValue;

  static const String prefsKey = 'wheeldeck.input_mapping';

  static InputMapping fromWireValue(String? value) => InputMapping.values
      .firstWhere((m) => m.wireValue == value, orElse: () => keyboard);

  /// Loads the persisted mapping, defaulting to keyboard.
  static Future<InputMapping> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  /// Persists the mapping.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}
