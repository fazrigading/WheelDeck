import 'package:shared_preferences/shared_preferences.dart';

import '../services/controller_visibility.dart';
import '../services/dashboard_input.dart';
import '../services/input_mapping.dart';
import '../services/pedal_input.dart';
import '../services/pedal_side.dart';

/// Single source of truth for settings (mapping, visibility, pedal sides, bindings).
class SettingsRepository {
  const SettingsRepository();

  Future<InputMapping> getMapping() => InputMapping.load();
  Future<void> setMapping(InputMapping mapping) => mapping.save();

  Future<ControllerVisibility> getVisibility() => ControllerVisibility.load();
  Future<void> setVisibility(ControllerVisibility v) => v.save();

  Future<PedalSides> getPedalSides() => PedalSides.load();

  Future<void> setPedalSide(PedalType pedal, PedalSide side) async {
    final current = await PedalSides.load();
    await current.copyWithSide(pedal, side).save();
  }

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
    await const ControllerVisibility(showClutch: false, showDashboard: true)
        .save();
    await PedalSides({}).save();
    await clearBindingOverrides();
  }
}
