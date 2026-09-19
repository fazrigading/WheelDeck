import 'package:shared_preferences/shared_preferences.dart';

import '../services/controller_preset.dart';
import '../services/controller_visibility.dart';
import '../services/dashboard_input.dart';
import '../services/dashboard_visibility.dart';
import '../services/engine_start_mode.dart';
import '../services/input_mapping.dart';
import '../services/pedal_input.dart';
import '../services/pedal_side.dart';
import '../services/spring_back.dart';
import '../services/wheel_mode.dart';

/// Single source of truth for settings (mapping, visibility, pedal sides,
/// wheel mode, rotation degrees, bindings).
class SettingsRepository {
  const SettingsRepository();

  Future<InputMapping> getMapping() => InputMapping.load();
  Future<void> setMapping(InputMapping mapping) => mapping.save();

  Future<ControllerVisibility> getVisibility() => ControllerVisibility.load();
  Future<void> setVisibility(ControllerVisibility v) => v.save();

  Future<GamePreset> getPreset() => GamePreset.load();
  Future<void> setPreset(GamePreset preset) => preset.save();

  Future<WheelMode> getWheelMode() => WheelMode.load();
  Future<void> setWheelMode(WheelMode mode) => mode.save();

  Future<int> getRotationDegree(GamePreset preset) =>
      RotationDegree.load(preset);
  Future<void> setRotationDegree(GamePreset preset, int degree) =>
      RotationDegree.save(preset, degree);

  Future<bool> getSpringBack() => SpringBack.load();
  Future<void> setSpringBack(bool value) => SpringBack.save(value);

  Future<PedalSides> getPedalSides() => PedalSides.load();

  Future<EngineStartMode> getEngineStartMode() => EngineStartMode.load();
  Future<void> setEngineStartMode(EngineStartMode mode) => mode.save();

  Future<DashboardVisibility> getDashboardVisibility() =>
      DashboardVisibility.load();
  Future<void> setDashboardVisibility(DashboardVisibility visibility) =>
      visibility.save();

  Future<void> setPedalSide(PedalType pedal, PedalSide side) async {
    final current = await PedalSides.load();
    await current.copyWithSide(pedal, side).save();
  }

  static String bindingKey(ControlId c, bool isGamepad) =>
      'wheeldeck.binding.${isGamepad ? 'gamepad' : 'keyboard'}.${c.wireValue}';

  Future<String?> getBindingOverride(ControlId c, bool isGamepad) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(bindingKey(c, isGamepad));
  }

  Future<void> setBindingOverride(
    ControlId c,
    bool isGamepad,
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(bindingKey(c, isGamepad), value);
  }

  Future<void> clearBindingOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in ControlId.values) {
      await prefs.remove(bindingKey(c, true));
      await prefs.remove(bindingKey(c, false));
    }
  }

  Future<void> resetAll() async {
    await InputMapping.fallback.save();
    await GamePreset.ets2.save();
    await const ControllerVisibility(
      showClutch: false,
      showDashboard: true,
    ).save();
    await PedalSides({}).save();
    await WheelMode.rotatable.save();
    await SpringBack.save(SpringBack.fallback);
    await EngineStartMode.holdConfirm.save();
    await const DashboardVisibility(DashboardVisibility.defaults).save();
    for (final preset in GamePreset.values) {
      await RotationDegree.save(preset, RotationDegree.fallback);
    }
    await clearBindingOverrides();
  }
}
