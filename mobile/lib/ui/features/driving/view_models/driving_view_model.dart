import 'package:flutter/foundation.dart';

import '../../../../data/repositories/connection_repository.dart';
import '../../../../data/repositories/pedal_repository.dart';
import '../../../../data/repositories/sensor_repository.dart';
import '../../../../domain/models/connection_target.dart';
import '../../../../domain/models/pedal_state.dart';
import '../../../../domain/models/steering_state.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/pedal_input.dart';

/// Presentation state for the driving view: steering angle, pedal pressures,
/// calibration gate, and wheel-drag fallback.
///
/// Injects repositories ([ConnectionRepository], [SensorRepository],
/// [PedalRepository]) plus the stateless [DashboardInput] event forwarder.
/// Exposes immutable snapshots ([steering], [pedals]); the View renders via
/// `ListenableBuilder` and delegates gestures to the command methods.
class DrivingViewModel extends ChangeNotifier {
  DrivingViewModel({
    required ConnectionRepository connectionRepository,
    required SensorRepository sensorRepository,
    required PedalRepository pedalRepository,
    required DashboardInput dashboardInput,
    bool initialAwaitingCalibration = false,
  })  : _connectionRepository = connectionRepository,
        _sensorRepository = sensorRepository,
        _pedalRepository = pedalRepository,
        _dashboardInput = dashboardInput,
        _awaitingCalibration = initialAwaitingCalibration {
    _sensorRepository.onAngleChanged(_onSensorAngle);
    _sensorRepository.start();
    _pedalRepository.onStateChanged(_onPedals);
    _dashboardInput.onControlActivated(
      (control, action) =>
          _connectionRepository.sendButtonEvent(control, action),
    );
  }

  final ConnectionRepository _connectionRepository;
  final SensorRepository _sensorRepository;
  final PedalRepository _pedalRepository;
  final DashboardInput _dashboardInput;

  SteeringState _steering = SteeringState.centered;
  bool _awaitingCalibration;
  bool _draggingWheel = false;
  double _dragBase = 0.0;

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

  /// Dashboard event forwarder for the dashboard panel.
  DashboardInput get dashboardInput => _dashboardInput;

  /// Applies the persisted dashboard mapping on the desktop. Best-effort:
  /// never throws, so driving still works when storage is unavailable.
  Future<void> init() async {
    try {
      final mapping = await InputMapping.load();
      _connectionRepository.sendMappingMode(mapping);
    } catch (_) {
      // Ignore: mapping hint is a session nicety, not required for input.
    }
  }

  /// Syncs the calibration gate with the lifecycle pause flag.
  void setAwaitingCalibration(bool value) {
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

  /// Re-centers the sensor and re-opens input. The caller reconnects via
  /// [lastTarget] when non-null.
  void confirmCalibration() {
    _sensorRepository.setCenter();
    setAwaitingCalibration(false);
  }

  /// Clears the calibration gate and disconnects.
  Future<void> disconnect() async {
    setAwaitingCalibration(false);
    await _connectionRepository.disconnect();
  }

  @override
  void dispose() {
    _sensorRepository.stop();
    _pedalRepository.dispose();
    super.dispose();
  }

  void _onSensorAngle(double angle) {
    if (_awaitingCalibration || _draggingWheel) return;
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
    );
  }
}
