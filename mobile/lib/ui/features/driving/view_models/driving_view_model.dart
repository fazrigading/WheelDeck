import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/pedal_repository.dart';
import '../../../../data/repositories/sensor_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/connection_target.dart';
import '../../../../domain/models/pedal_state.dart';
import '../../../../domain/models/steering_state.dart';
import '../../../../data/services/controller_preset.dart';
import '../../../../data/services/controller_visibility.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import '../../../../data/services/dashboard_visibility.dart';
import '../../../../data/services/driving_layout.dart';
import '../../../../data/services/engine_start_mode.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/layout_profile.dart';
import '../../../../data/services/pedal_input.dart';
import '../../../../data/services/pedal_side.dart';
import '../../../../data/services/camera_control_type.dart';
import '../../../../data/services/camera_pad_mode.dart';
import '../../../../data/services/spring_back.dart';
import '../../../../data/services/wheel_mode.dart';

/// Presentation state for the driving view: steering angle, pedal pressures,
/// calibration gate, and wheel-drag fallback.
///
/// Injects repositories ([ConnectionRepository], [SensorRepository],
/// [PedalRepository]) plus the stateless [DashboardInput] event forwarder.
/// Exposes immutable snapshots ([steering], [pedals]); the View renders via
/// `ListenableBuilder` and delegates gestures to the command methods.
class DrivingViewModel extends ChangeNotifier {
  DrivingViewModel({
    required this._connectionRepository,
    required this._sensorRepository,
    required this._pedalRepository,
    required this._dashboardInput,
    bool initialAwaitingCalibration = false,
  }) : _awaitingCalibration = initialAwaitingCalibration {
    _sendGate = DashboardSendGate(
      send: (control, action) =>
          _connectionRepository.sendButtonEvent(control, action),
      bindingFor: _bindingFor,
    );
    _sensorRepository.onAngleChanged(_onSensorAngle);
    _sensorRepository.start();
    _pedalRepository.onStateChanged(_onPedals);
    _dashboardInput.onControlActivated(
      (control, action) => _sendGate.handle(control, action),
    );
  }

  final ConnectionRepository _connectionRepository;
  final SensorRepository _sensorRepository;
  final PedalRepository _pedalRepository;
  final DashboardInput _dashboardInput;
  late final DashboardSendGate _sendGate;

  SteeringState _steering = SteeringState.centered;
  bool _awaitingCalibration;
  bool _draggingWheel = false;
  double _dragBase = 0.0;
  Map<PedalType, PedalSide> _pedalSides = PedalSides.defaults().asMap();
  ControllerVisibility _visibility = ControllerVisibility.fallback;
  GamePreset _preset = GamePreset.fallback;
  InputMapping _mapping = InputMapping.fallback;
  Map<String, String> _bindingOverrides = {};
  WheelMode _wheelMode = WheelMode.fallback;
  int _rotationDegree = RotationDegree.fallback;
  bool _springBack = SpringBack.fallback;
  CameraPadMode _cameraPadMode = CameraPadMode.fallback;
  CameraControlType _cameraControlType = CameraControlType.fallback;
  EngineStartMode _engineStartMode = EngineStartMode.fallback;
  Set<ControlId> _visibleExtras = DashboardVisibility.defaults;
  String _activeProfile = LayoutProfileStore.defaultProfileName;
  DrivingLayout _storedLayout = DrivingLayout.sequential();
  double _cameraX = 0.0;
  double _cameraY = 0.0;

  /// Unsaved editor result for this session; cleared on profile switches
  /// and settings refreshes.
  DrivingLayout? _sessionLayout;

  /// Normalized steering angle snapshot (-1.0..1.0).
  SteeringState get steering => _steering;

  /// Pedal pressure snapshot.
  PedalState get pedals => _pedalRepository.state;

  /// True while input is gated behind re-confirmed calibration.
  bool get awaitingCalibration => _awaitingCalibration;

  /// Last connection target, for reconnecting after calibration.
  ConnectionTarget? get lastTarget => _connectionRepository.lastTarget;

  /// Raw pedal input for the pedal panel during migration.
  PedalInput get pedalInput => _pedalRepository.input;

  /// Phone-held send gate: drops unbound controls, cycles the headlight IDs,
  /// and holds signal/hazard blink state.
  DashboardSendGate get sendGate => _sendGate;

  /// Public per-mode binding resolver for the grid's unbound visuals.
  String bindingFor(ControlId control) => _bindingFor(control);

  /// Current mapping mode, for the binder dialog label.
  InputMapping get mapping => _mapping;

  /// Active layout profile name. Layout only; bindings and the rest stay
  /// global (REQ-008).
  String get activeProfile => _activeProfile;

  /// Layout the grid renders: the session edit when one is applied, else
  /// the stored profile layout.
  DrivingLayout get activeLayout => _sessionLayout ?? _storedLayout;

  /// Applies an editor result for this session. Not persisted.
  void applySessionLayout(DrivingLayout layout) {
    _sessionLayout = layout;
    notifyListeners();
  }

  /// Switches to the named profile, clearing any session edit. Best-effort:
  /// never throws; unknown names fall back to the Sequential preset.
  Future<void> selectProfile(String name) async {
    try {
      _storedLayout = await LayoutProfileStore.layoutFor(name);
      _activeProfile = name;
      _sessionLayout = null;
      notifyListeners();
      await LayoutProfileStore.saveActiveName(name);
    } catch (_) {}
  }

  /// Persists a per-mode binding override (empty means unbound) and refreshes
  /// the gate resolution. Best-effort: never throws.
  Future<void> setBinding(ControlId control, String value) async {
    final isGamepad = _mapping == InputMapping.gamepad;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = SettingsRepository.bindingKey(control, isGamepad);
      await prefs.setString(key, value);
      _bindingOverrides[key] = value;
      notifyListeners();
    } catch (_) {}
  }

  /// Resolves the per-mode binding for [control]: user override first, then
  /// the preset default. Empty means unbound; the gate sends nothing.
  String _bindingFor(ControlId control) {
    return bindingForMode(
      control,
      _mapping == InputMapping.gamepad,
    );
  }

  /// Resolves [control]'s binding for an explicit input mode, with the same
  /// override-then-preset rule as [bindingFor]. The editor uses it to offer
  /// every control bound in either mode.
  String bindingForMode(ControlId control, bool isGamepad) {
    final override =
        _bindingOverrides[SettingsRepository.bindingKey(control, isGamepad)];
    // A stored override wins verbatim: empty means unbound (send nothing).
    if (override != null) return override;
    return _preset.bindingFor(control, isGamepad);
  }

  /// Dashboard event forwarder for the dashboard panel.
  DashboardInput get dashboardInput => _dashboardInput;

  Map<PedalType, PedalSide> get pedalSides => Map.unmodifiable(_pedalSides);
  ControllerVisibility get visibility => _visibility;

  /// True in rotatable mode: the finger-drag wheel drives steering, the gyro
  /// sensor is ignored, and the calibration gate never engages.
  bool get isRotatable => _wheelMode == WheelMode.rotatable;

  /// Selected lock-to-lock range in degrees for the rotatable wheel.
  int get rotationDegree => _rotationDegree;

  /// Whether the rotatable wheel animates back to zero on release. When
  /// off, the wheel holds its released angle until dragged back.
  bool get springBack => _springBack;
  CameraPadMode get cameraPadMode => _cameraPadMode;

  /// Which camera control the pad renders; the pad widget dispatches on it.
  CameraControlType get cameraControlType => _cameraControlType;

  /// Engine-start interaction mode (hold-confirm vs single press).
  EngineStartMode get engineStartMode => _engineStartMode;

  /// Extra dashboard controls shown in the grid.
  Set<ControlId> get visibleExtras => Set.unmodifiable(_visibleExtras);

  /// Applies the persisted dashboard mapping on the desktop. Best-effort:
  /// never throws, so driving still works when storage is unavailable.
  Future<void> init() async {
    try {
      _mapping = await InputMapping.load();
      _connectionRepository.sendMappingMode(_mapping);
    } catch (_) {}
    try {
      final sides = await PedalSides.load();
      _pedalSides = sides.asMap();
    } catch (_) {}
    try {
      _visibility = await ControllerVisibility.load();
    } catch (_) {}
    await _loadWheelState();
    await _loadBindings();
    await _loadDashboardState();
    await _loadProfile();
    try {
      _connectionRepository.sendMappingMode(_mapping, preset: _activeProfile);
    } catch (_) {}
    if (isRotatable) _awaitingCalibration = false;
    notifyListeners();
  }

  Future<void> refreshPedalSides() async {
    try {
      final sides = await PedalSides.load();
      _pedalSides = sides.asMap();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshVisibility() async {
    try {
      _visibility = await ControllerVisibility.load();
      notifyListeners();
    } catch (_) {}
  }

  /// Best-effort load of preset, wheel mode, and per-preset degree.
  Future<void> _loadWheelState() async {
    try {
      _preset = await GamePreset.load();
    } catch (_) {}
    try {
      _wheelMode = await WheelMode.load();
    } catch (_) {}
    try {
      _rotationDegree = await RotationDegree.load(_preset);
    } catch (_) {}
    try {
      _springBack = await SpringBack.load();
    } catch (_) {}
    try {
      _cameraPadMode = await CameraPadMode.load();
    } catch (_) {}
    try {
      _cameraControlType = await CameraControlType.load();
    } catch (_) {}
  }

  /// Best-effort load of the active profile name and its layout.
  Future<void> _loadProfile() async {
    try {
      _activeProfile = await LayoutProfileStore.loadActiveName();
      _storedLayout = await LayoutProfileStore.layoutFor(_activeProfile);
    } catch (_) {}
  }

  Future<void> refreshWheel() async {
    await _loadWheelState();
    if (isRotatable) _awaitingCalibration = false;
    notifyListeners();
  }

  /// The camera pad's center hold switches the key set; the driving view
  /// model owns the mode (REQ-017) and persists the change.
  Future<void> toggleCameraPadMode() async {
    final next = _cameraPadMode.other;
    _cameraPadMode = next;
    notifyListeners();
    await next.save();
  }

  Future<void> refreshSettings() async {
    await refreshPedalSides();
    await refreshVisibility();
    await refreshWheel();
    try {
      _mapping = await InputMapping.load();
    } catch (_) {}
    await _loadBindings();
    await _loadDashboardState();
    _sessionLayout = null;
    await _loadProfile();
  }

  /// Best-effort load of engine-start mode and visible dashboard extras.
  Future<void> _loadDashboardState() async {
    try {
      _engineStartMode = await EngineStartMode.load();
    } catch (_) {}
    try {
      _visibleExtras = (await DashboardVisibility.load()).visibleExtras;
    } catch (_) {}
  }

  /// Best-effort load of per-mode binding overrides, so the send gate drops
  /// unbound controls. Never throws.
  Future<void> _loadBindings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isGamepad = _mapping == InputMapping.gamepad;
      final overrides = <String, String>{};
      for (final c in ControlId.values) {
        final key = SettingsRepository.bindingKey(c, isGamepad);
        final value = prefs.getString(key);
        if (value != null) overrides[key] = value;
      }
      _bindingOverrides = overrides;
    } catch (_) {}
  }

  /// Syncs the calibration gate with the lifecycle pause flag. Rotatable
  /// steering cannot drift, so the gate never engages there.
  void setAwaitingCalibration(bool value) {
    if (isRotatable) value = false;
    if (_awaitingCalibration == value) return;
    _awaitingCalibration = value;
    notifyListeners();
  }

  /// Sets the pressure directly while the user drags a pedal bar.
  void setPedalPressure(PedalType pedal, double pressure) =>
      _pedalRepository.setPressure(pedal, pressure);

  /// Releases a pedal so it springs back toward rest.
  void releasePedal(PedalType pedal) => _pedalRepository.release(pedal);

  /// Starts a horizontal-drag fallback gesture on the wheel.
  void onWheelDragStart() {
    _draggingWheel = true;
    _dragBase = _steering.angle;
  }

  /// Applies a horizontal-drag delta (~200 logical px = full lock).
  void onWheelDragUpdate(double dx) {
    final angle = (_dragBase + dx / 200).clamp(-1.0, 1.0).toDouble();
    _steering = SteeringState(angle: angle);
    notifyListeners();
    _sendState();
  }

  /// Ends the drag gesture and recenters the gyro on the dragged angle.
  void onWheelDragEnd() {
    _draggingWheel = false;
    _dragBase = _steering.angle;
    _sensorRepository.setCenter();
  }

  /// Applies rotatable-wheel steering. Bypasses the gyro deadband so finger
  /// feedback stays 1:1; always transmits, so spring-back to zero is sent.
  ///
  /// Deliberately does not notify: the rotatable wheel owns its drag visuals
  /// internally, so a notification would rebuild the whole block grid on
  /// every drag update. Nothing else in rotatable mode reads the angle.
  void setRotatableSteering(double angle) {
    _steering = SteeringState(angle: angle.clamp(-1.0, 1.0).toDouble());
    _sendState();
  }

  /// Reports analog camera look. Forwards through the state stream without
  /// notifying — nothing renders the values — mirroring setRotatableSteering.
  void setAnalogCamera(double x, double y) {
    _cameraX = x.clamp(-1.0, 1.0).toDouble();
    _cameraY = y.clamp(-1.0, 1.0).toDouble();
    _sendState();
  }

  /// Re-centers the sensor and re-opens input. The caller reconnects via
  /// [lastTarget] when non-null.
  void confirmCalibration() {
    _sensorRepository.setCenter();
    setAwaitingCalibration(false);
  }

  /// Manual zeroing for drift/phone-move — does not touch calibration gate.
  void recalibrate() {
    _sensorRepository.setCenter();
    _steering = SteeringState.centered;
    notifyListeners();
  }

  /// Clears the calibration gate and disconnects.
  Future<void> disconnect() async {
    setAwaitingCalibration(false);
    await _connectionRepository.disconnect();
  }

  @override
  void dispose() {
    _sendGate.dispose();
    _sensorRepository.stop();
    _pedalRepository.dispose();
    super.dispose();
  }

  void _onSensorAngle(double angle) {
    if (_awaitingCalibration || _draggingWheel || isRotatable) return;
    if ((_steering.angle - angle).abs() < 0.002) return;
    _steering = SteeringState(angle: angle);
    notifyListeners();
    _sendState();
  }

  void _onPedals(PedalState state) {
    if (_awaitingCalibration) return;
    notifyListeners();
    _sendState();
  }

  void _sendState() {
    final pedals = _pedalRepository.state;
    _connectionRepository.sendState(
      steering: _steering.angle,
      accelerator: pedals.accelerator,
      brake: pedals.brake,
      clutch: pedals.clutch,
      cameraX: _cameraX,
      cameraY: _cameraY,
    );
  }
}
