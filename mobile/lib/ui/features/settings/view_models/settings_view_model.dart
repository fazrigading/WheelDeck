import 'package:flutter/foundation.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/controller_preset.dart';
import '../../../../data/services/controller_visibility.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/pedal_input.dart';
import '../../../../data/services/pedal_side.dart';

/// Presentation state for the settings page.
///
/// Injects [SettingsRepository] (persisted choice) and [ConnectionRepository]
/// (forwards the choice to the desktop). The View renders via
/// `ListenableBuilder`.
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required this._settingsRepository,
    required this._connectionRepository,
  });

  final SettingsRepository _settingsRepository;
  final ConnectionRepository _connectionRepository;

  InputMapping _mapping = InputMapping.keyboard;
  ControllerVisibility _visibility = ControllerVisibility.fallback;
  Map<PedalType, PedalSide> _pedalSides = PedalSides.defaults().asMap();
  GamePreset _preset = GamePreset.ets2;
  final Map<String, String> _bindingOverrides = {};
  bool _loaded = false;

  InputMapping get mapping => _mapping;
  ControllerVisibility get visibility => _visibility;
  Map<PedalType, PedalSide> get pedalSides => Map.unmodifiable(_pedalSides);
  GamePreset get preset => _preset;
  bool get loaded => _loaded;

  Future<void> init() async {
    try {
      _mapping = await _settingsRepository.getMapping();
    } catch (_) {}
    try {
      _visibility = await _settingsRepository.getVisibility();
    } catch (_) {}
    try {
      final sides = await _settingsRepository.getPedalSides();
      _pedalSides = sides.asMap();
    } catch (_) {}
    // Load binding overrides for both modes
    for (final c in ControlId.values) {
      try {
        final kb = await _settingsRepository.getBindingOverride(c, false);
        if (kb != null) _bindingOverrides['keyboard.${c.wireValue}'] = kb;
        final gp = await _settingsRepository.getBindingOverride(c, true);
        if (gp != null) _bindingOverrides['gamepad.${c.wireValue}'] = gp;
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  String bindingFor(ControlId c) {
    final isGamepad = _mapping == InputMapping.gamepad;
    final key = '${isGamepad ? 'gamepad' : 'keyboard'}.${c.wireValue}';
    final override = _bindingOverrides[key];
    if (override != null && override.isNotEmpty) return override;
    return _preset.bindingFor(c, isGamepad);
  }

  Future<void> select(InputMapping mapping) async {
    _mapping = mapping;
    notifyListeners();
    await _settingsRepository.setMapping(mapping);
    _connectionRepository.sendMappingMode(mapping);
  }

  Future<void> selectVisibility(ControllerVisibility v) async {
    _visibility = v;
    notifyListeners();
    await _settingsRepository.setVisibility(v);
  }

  Future<void> selectPedalSide(PedalType pedal, PedalSide side) async {
    _pedalSides[pedal] = side;
    notifyListeners();
    await _settingsRepository.setPedalSide(pedal, side);
  }

  void selectPreset(GamePreset v) {
    _preset = v;
    notifyListeners();
  }

  Future<void> setBinding(ControlId c, String value) async {
    final isGamepad = _mapping == InputMapping.gamepad;
    final key = '${isGamepad ? 'gamepad' : 'keyboard'}.${c.wireValue}';
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _bindingOverrides.remove(key);
    } else {
      _bindingOverrides[key] = trimmed;
    }
    notifyListeners();
    await _settingsRepository.setBindingOverride(c, isGamepad, trimmed);
  }

  Future<void> resetToDefaults() async {
    _mapping = InputMapping.keyboard;
    _visibility = ControllerVisibility.fallback;
    _pedalSides = PedalSides.defaults().asMap();
    _preset = GamePreset.ets2;
    _bindingOverrides.clear();
    notifyListeners();
    await _settingsRepository.resetAll();
    _connectionRepository.sendMappingMode(_mapping);
  }
}
