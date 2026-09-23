import 'package:shared_preferences/shared_preferences.dart';

/// Which camera control the rotatable camera pad renders. The D-pad type is
/// the v2 plan's pad and stays the default; Simple and Analog arrive with
/// their own issues. (Semi-Analog was deleted in Phase 1: no design.)
enum CameraControlType {
  dpad('dpad', 'D-pad'),
  simple('simple', 'Simple'),
  analog('analog', 'Analog');

  const CameraControlType(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static const String prefsKey = 'wheeldeck.camera_control_type';
  static const CameraControlType fallback = dpad;

  static CameraControlType fromWireValue(String? v) =>
      CameraControlType.values.firstWhere(
        (t) => t.wireValue == v,
        orElse: () => fallback,
      );

  static Future<CameraControlType> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}
