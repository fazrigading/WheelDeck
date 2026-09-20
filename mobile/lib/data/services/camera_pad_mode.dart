import 'package:shared_preferences/shared_preferences.dart';

/// Which key set the rotatable camera pad sends: the numpad block or the
/// arrow keys. The pad itself is the switch surface — a three-second hold
/// on its center cell toggles the mode (REQ-017).
enum CameraPadMode {
  numpad('numpad'),
  arrow('arrow');

  const CameraPadMode(this.wireValue);
  final String wireValue;

  static const String prefsKey = 'wheeldeck.camera_pad_mode';
  static const CameraPadMode fallback = numpad;

  static CameraPadMode fromWireValue(String? v) => CameraPadMode.values
      .firstWhere((m) => m.wireValue == v, orElse: () => fallback);

  static Future<CameraPadMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  /// The other mode; the pad's center hold switches to it.
  CameraPadMode get other => this == numpad ? arrow : numpad;

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}
