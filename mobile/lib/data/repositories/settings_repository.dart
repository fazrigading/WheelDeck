import '../services/controller_type.dart';
import '../services/input_mapping.dart';
import '../services/pedal_layout.dart';

/// Single source of truth for settings (mapping, controller type, pedal layout).
class SettingsRepository {
  const SettingsRepository();

  Future<InputMapping> getMapping() => InputMapping.load();
  Future<void> setMapping(InputMapping mapping) => mapping.save();

  Future<ControllerType> getControllerType() => ControllerType.load();
  Future<void> setControllerType(ControllerType v) => v.save();

  Future<PedalLayout> getPedalLayout() => PedalLayout.load();
  Future<void> setPedalLayout(PedalLayout v) => v.save();

  Future<void> resetAll() async {
    await InputMapping.keyboard.save();
    await ControllerType.full.save();
    await PedalLayout.layoutA.save();
  }
}
