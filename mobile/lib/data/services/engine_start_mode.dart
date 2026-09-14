import 'package:shared_preferences/shared_preferences.dart';

/// How the engine-start control fires: hold-to-confirm or single press.
enum EngineStartMode {
  holdConfirm('hold_confirm', 'Hold to confirm'),
  singlePress('single_press', 'Single press');

  const EngineStartMode(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static const String prefsKey = 'wheeldeck.engine_start_mode';
  static const EngineStartMode fallback = holdConfirm;

  static EngineStartMode fromWireValue(String? v) =>
      EngineStartMode.values.firstWhere(
        (m) => m.wireValue == v,
        orElse: () => fallback,
      );

  static Future<EngineStartMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}
