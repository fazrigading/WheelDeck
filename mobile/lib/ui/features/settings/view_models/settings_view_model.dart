import 'package:flutter/foundation.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/controller_preset.dart';
import '../../../../data/services/controller_visibility.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_visibility.dart';
import '../../../../data/services/engine_start_mode.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/layout_profile.dart';
import '../../../../data/services/pedal_input.dart';
import '../../../../data/services/pedal_side.dart';
import '../../../../data/services/camera_pad_mode.dart';
import '../../../../data/services/spring_back.dart';
import '../../../../data/services/wheel_mode.dart';

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

  InputMapping _mapping = InputMapping.gamepad;
  ControllerVisibility _visibility = ControllerVisibility.fallback;
  Map<PedalType, PedalSide> _pedalSides = PedalSides.defaults().asMap();
  GamePreset _preset = GamePreset.ets2;
  WheelMode _wheelMode = WheelMode.rotatable;
  int _rotationDegree = RotationDegree.fallback;
  bool _springBack = SpringBack.fallback;
  CameraPadMode _cameraPadMode = CameraPadMode.fallback;
  EngineStartMode _engineStartMode = EngineStartMode.fallback;
  Set<ControlId> _visibleExtras = DashboardVisibility.defaults;
  final Map<String, String> _bindingOverrides = {};
  bool _loaded = false;
  List<LayoutProfile> _layoutProfiles = const [];
  String _activeLayoutProfile = LayoutProfileStore.defaultProfileName;

  InputMapping get mapping => _mapping;
  ControllerVisibility get visibility => _visibility;
  Map<PedalType, PedalSide> get pedalSides => Map.unmodifiable(_pedalSides);
  GamePreset get preset => _preset;
  WheelMode get wheelMode => _wheelMode;
  int get rotationDegree => _rotationDegree;

  /// Whether the rotatable wheel animates back to zero on release.
  bool get springBack => _springBack;
  CameraPadMode get cameraPadMode => _cameraPadMode;
  EngineStartMode get engineStartMode => _engineStartMode;
  Set<ControlId> get visibleExtras => Set.unmodifiable(_visibleExtras);
  bool get loaded => _loaded;

  /// Every profile from the store: developer presets first, then user
  /// profiles.
  List<LayoutProfile> get layoutProfiles =>
      List.unmodifiable(_layoutProfiles);

  /// Active layout profile name; the driving view resolves the layout.
  String get activeLayoutProfile => _activeLayoutProfile;

  /// Best-effort profile load. Never throws.
  Future<void> loadLayoutProfiles() async {
    try {
      _layoutProfiles = await LayoutProfileStore.loadAll();
      _activeLayoutProfile = await LayoutProfileStore.loadActiveName();
      notifyListeners();
    } catch (_) {}
  }

  /// Selects a profile and persists it as active. The driving view applies
  /// the layout on return through its settings refresh; the preset name
  /// rides the mapping frame so the desktop scopes its tables (REQ-018).
  Future<void> selectLayoutProfile(String name) async {
    try {
      _activeLayoutProfile = name;
      notifyListeners();
      await LayoutProfileStore.saveActiveName(name);
      _connectionRepository.sendMappingMode(_mapping, preset: name);
    } catch (_) {}
  }

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
    try {
      _preset = await _settingsRepository.getPreset();
    } catch (_) {}
    try {
      _wheelMode = await _settingsRepository.getWheelMode();
    } catch (_) {}
    try {
      _rotationDegree = await _settingsRepository.getRotationDegree(_preset);
    } catch (_) {}
    try {
      _springBack = await _settingsRepository.getSpringBack();
    } catch (_) {}
    try {
      _cameraPadMode = await _settingsRepository.getCameraPadMode();
    } catch (_) {}
    try {
      _engineStartMode = await _settingsRepository.getEngineStartMode();
    } catch (_) {}
    try {
      _visibleExtras =
          (await _settingsRepository.getDashboardVisibility()).visibleExtras;
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
    await loadLayoutProfiles();
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

  Future<void> selectWheelMode(WheelMode mode) async {
    _wheelMode = mode;
    notifyListeners();
    await _settingsRepository.setWheelMode(mode);
  }

  Future<void> selectRotationDegree(int degree) async {
    _rotationDegree = degree;
    notifyListeners();
    await _settingsRepository.setRotationDegree(_preset, degree);
  }

  Future<void> selectSpringBack(bool value) async {
    _springBack = value;
    notifyListeners();
    await _settingsRepository.setSpringBack(value);
  }

  Future<void> selectCameraPadMode(CameraPadMode mode) async {
    _cameraPadMode = mode;
    notifyListeners();
    await _settingsRepository.setCameraPadMode(mode);
  }

  Future<void> selectEngineStartMode(EngineStartMode mode) async {
    _engineStartMode = mode;
    notifyListeners();
    await _settingsRepository.setEngineStartMode(mode);
  }

  Future<void> toggleExtraControl(ControlId control) async {
    final next = Set<ControlId>.of(_visibleExtras);
    if (!next.remove(control)) next.add(control);
    _visibleExtras = next;
    notifyListeners();
    await _settingsRepository.setDashboardVisibility(DashboardVisibility(next));
  }

  Future<void> selectPreset(GamePreset v) async {
    _preset = v;
    try {
      _rotationDegree = await _settingsRepository.getRotationDegree(v);
    } catch (_) {
      _rotationDegree = RotationDegree.fallback;
    }
    notifyListeners();
    await _settingsRepository.setPreset(v);
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
    _mapping = InputMapping.gamepad;
    _visibility = ControllerVisibility.fallback;
    _pedalSides = PedalSides.defaults().asMap();
    _preset = GamePreset.ets2;
    _wheelMode = WheelMode.rotatable;
    _rotationDegree = RotationDegree.fallback;
    _springBack = SpringBack.fallback;
    _cameraPadMode = CameraPadMode.fallback;
    _engineStartMode = EngineStartMode.fallback;
    _visibleExtras = DashboardVisibility.defaults;
    _bindingOverrides.clear();
    _activeLayoutProfile = LayoutProfileStore.defaultProfileName;
    await LayoutProfileStore.saveActiveName(_activeLayoutProfile);
    notifyListeners();
    await _settingsRepository.resetAll();
    _connectionRepository.sendMappingMode(_mapping);
  }
}
