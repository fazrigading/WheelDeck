import 'package:shared_preferences/shared_preferences.dart';

import '../services/controller_type.dart';
import '../services/dashboard_input.dart';
import '../services/input_mapping.dart';
import '../services/pedal_layout.dart';

/// Single source of truth for settings (mapping, controller type, pedal layout, bindings).
class SettingsRepository {
  const SettingsRepository();

  Future<InputMapping> getMapping() => InputMapping.load();
  Future<void> setMapping(InputMapping mapping) => mapping.save();

  Future<ControllerType> getControllerType() => ControllerType.load();
  Future<void> setControllerType(ControllerType v) => v.save();

  Future<PedalLayout> getPedalLayout() => PedalLayout.load();
  Future<void> setPedalLayout(PedalLayout v) => v.save();

  static String _bindingKey(ControlId c, bool isGamepad) =>
      'wheeldeck.binding.${isGamepad ? 'gamepad' : 'keyboard'}.${c.wireValue}';

  Future<String?> getBindingOverride(ControlId c, bool isGamepad) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bindingKey(c, isGamepad));
  }

  Future<void> setBindingOverride(ControlId c, bool isGamepad, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bindingKey(c, isGamepad), value);
  }

  Future<void> clearBindingOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in ControlId.values) {
      await prefs.remove(_bindingKey(c, true));
      await prefs.remove(_bindingKey(c, false));
    }
  }

  Future<void> resetAll() async {
    await InputMapping.keyboard.save();
    await ControllerType.full.save();
    await PedalLayout.layoutA.save();
    await clearBindingOverrides();
  }
}
