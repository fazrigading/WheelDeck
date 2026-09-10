import 'package:shared_preferences/shared_preferences.dart';

/// Which inputs are active on the driving screen.
enum ControllerType {
  steeringOnly('steeringOnly', 'Steering only'),
  steering3Pedals('steering3Pedals', 'Steering + 3 pedals'),
  steering2Pedals('steering2Pedals', 'Steering + 2 pedals'),
  steeringDashboard('steeringDashboard', 'Steering + dashboard'),
  full('full', 'Full (wheel + pedals + dashboard)');

  const ControllerType(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static const String prefsKey = 'wheeldeck.controller_type';
  static const ControllerType fallback = full;

  static ControllerType fromWireValue(String? v) =>
      ControllerType.values.firstWhere((e) => e.wireValue == v, orElse: () => fallback);

  static Future<ControllerType> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}
