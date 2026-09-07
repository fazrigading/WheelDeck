import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../input/dashboard_input.dart';
import '../../input/input_mapping.dart';
import '../../input/pedal_input.dart';
import '../../input/steering_sensor.dart';
import '../../state/connection_coordinator.dart';
import '../../state/lifecycle_observer.dart';
import '../dashboard/dashboard_panel.dart';
import '../pedals/pedal_panel.dart';
import '../settings/settings_screen.dart';
import '../wheel/wheel_view.dart';

/// The post-connection driving view: steering wheel, pedal bars, and dashboard
/// controls in a landscape row layout.
///
/// Shown only after [ConnectionStatus] reaches `connected`. Sends pedal and
/// dashboard events through the [ConnectionCoordinator]'s client as they
/// arrive, satisfying the PRD latency target of sub-50ms round trip.
///
/// Steering comes from the gyroscope Z-axis (roll around the screen normal,
/// the axis the phone rotates around when held like a wheel) integrated into
/// an angle via [SteeringSensor], with a horizontal-drag fallback on the
/// wheel for desks/emulators without sensors.
///
/// Pauses input and disconnects on lifecycle interruptions (call, screen lock,
/// backgrounding). On resume, the user must re-confirm steering calibration
/// before input resumes.
class DrivingView extends StatefulWidget {
  const DrivingView({super.key, required this.coordinator});

  final ConnectionCoordinator coordinator;

  @override
  State<DrivingView> createState() => _DrivingViewState();
}

class _DrivingViewState extends State<DrivingView> {
  double _steeringAngle = 0.0;
  late final PedalInput _pedalInput;
  late final DashboardInput _dashboardInput;
  late final SteeringSensor _steeringSensor;
  late final LifecycleObserver _lifecycleObserver;
  List<DeviceOrientation>? _previousOrientations;
  bool _awaitingCalibration = false;
  bool _draggingWheel = false;
  double _dragBase = 0.0;
  double _rawGyroAngle = 0.0;
  DateTime? _lastGyroAt;

  @override
  void initState() {
    super.initState();

    _lifecycleObserver = LifecycleObserver(
      coordinator: widget.coordinator,
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _lockOrientation();
    _hideSystemUI();

    _steeringSensor = SteeringSensor(
      rawAngleStream: gyroscopeEventStream().map((e) {
        // Integrate Z-axis angular velocity (rad/s) into a raw angle.
        // setCenter() recenters drift; ±pi range leaves headroom around the
        // pi/4 full-lock angle.
        final now = DateTime.now();
        final dt = _lastGyroAt == null
            ? 0.016
            : now.difference(_lastGyroAt!).inMicroseconds / 1000000.0;
        _lastGyroAt = now;
        _rawGyroAngle += e.z * dt.clamp(0.0, 0.1);
        return _rawGyroAngle.clamp(-math.pi, math.pi);
      }),
    );
    _steeringSensor.onAngleChanged(_onSteeringChanged);
    _steeringSensor.start();

    _pedalInput = PedalInput();
    _pedalInput.onPressureChanged(_onPedalChanged);

    _dashboardInput = DashboardInput();
    _dashboardInput.onControlActivated((control, action) {
      widget.coordinator.client.sendButtonEvent(control, action);
    });

    // Apply the persisted dashboard mapping on the desktop for this session.
    InputMapping.load().then(
      (mapping) => widget.coordinator.client.sendMappingMode(mapping),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _restoreOrientation();
    _restoreSystemUI();
    _steeringSensor.stop();
    _pedalInput.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DrivingView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.coordinator.isPaused && !_awaitingCalibration) {
      _awaitingCalibration = true;
    }

    if (!widget.coordinator.isPaused && _awaitingCalibration) {
      _awaitingCalibration = false;
    }
  }

  void _onSteeringChanged(double angle) {
    if (_awaitingCalibration || _draggingWheel) return;
    if ((_steeringAngle - angle).abs() < 0.002) return;
    setState(() => _steeringAngle = angle);
    _sendState();
  }

  void _onPedalChanged(PedalType pedal, double pressure) {
    if (_awaitingCalibration) return;
    setState(() {});
    _sendState();
  }

  void _sendState() {
    widget.coordinator.client.sendState(
      steering: _steeringAngle,
      accelerator: _pedalInput.pressureOf(PedalType.accelerator),
      brake: _pedalInput.pressureOf(PedalType.brake),
      clutch: _pedalInput.pressureOf(PedalType.clutch),
    );
  }

  void _onWheelDragStart(DragStartDetails details) {
    _draggingWheel = true;
    _dragBase = _steeringAngle;
  }

  void _onWheelDragUpdate(DragUpdateDetails details) {
    // ~200 logical px of horizontal drag = full lock. Works without sensors
    // (emulators, desks) and gives immediate visual + network feedback.
    final angle = (_dragBase + details.delta.dx / 200).clamp(-1.0, 1.0);
    setState(() => _steeringAngle = angle);
    _sendState();
  }

  void _onWheelDragEnd() {
    _draggingWheel = false;
    _dragBase = _steeringAngle;
    _steeringSensor.setCenter();
  }

  void _onCalibrationConfirmed() async {
    _steeringSensor.setCenter();
    setState(() {
      _awaitingCalibration = false;
    });

    final target = widget.coordinator.client.lastTarget;
    if (target != null) {
      await widget.coordinator.connect(target);
    }
  }

  void _onDisconnect() {
    setState(() {
      _awaitingCalibration = false;
    });
    widget.coordinator.disconnect();
  }

  void _lockOrientation() {
    _previousOrientations = null;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _restoreOrientation() {
    final previous = _previousOrientations;
    if (previous != null) {
      SystemChrome.setPreferredOrientations(previous);
    } else {
      SystemChrome.setPreferredOrientations([]);
    }
  }

  void _hideSystemUI() {
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _restoreSystemUI() {
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(client: widget.coordinator.client),
              ),
            ),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.wifi_off),
            onPressed: _onDisconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: SafeArea(
        child: _awaitingCalibration
            ? CalibrationOverlay(
                angle: _steeringAngle,
                onConfirmed: _onCalibrationConfirmed,
              )
            : _buildDrivingContent(),
      ),
    );
  }

  Widget _buildDrivingContent() {
    // Landscape-locked: wheel left, pedals + dashboard right. Wheel fills
    // available height instead of the fixed 280px portrait box.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wheelSize =
            (math.min(constraints.maxWidth * 0.42, constraints.maxHeight) - 16)
                .clamp(160.0, 480.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: GestureDetector(
                  onHorizontalDragStart: _onWheelDragStart,
                  onHorizontalDragUpdate: _onWheelDragUpdate,
                  onHorizontalDragEnd: (_) => _onWheelDragEnd(),
                  onDoubleTap: () => _onWheelDragEnd(),
                  child: WheelView(angle: _steeringAngle, size: wheelSize),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: PedalPanel(input: _pedalInput),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: DashboardPanel(input: _dashboardInput),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Overlay shown after a lifecycle interruption, requiring the user to
/// re-confirm the steering center before input resumes.
class CalibrationOverlay extends StatelessWidget {
  const CalibrationOverlay({
    super.key,
    required this.angle,
    required this.onConfirmed,
  });

  final double angle;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.screen_lock_rotation,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Session interrupted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'The connection was paused. Please re-confirm\nyour steering center before resuming.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Text(
            'Current steering angle: ${angle.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onConfirmed,
            child: const Text('Resume driving'),
          ),
        ],
      ),
    );
  }
}
