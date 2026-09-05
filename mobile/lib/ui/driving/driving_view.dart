import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../input/dashboard_input.dart';
import '../../input/pedal_input.dart';
import '../../state/connection_coordinator.dart';
import '../../state/lifecycle_observer.dart';
import '../dashboard/dashboard_panel.dart';
import '../pedals/pedal_panel.dart';
import '../wheel/wheel_view.dart';

/// The post-connection driving view: steering wheel, pedal bars, and dashboard
/// controls in a single-column layout.
///
/// Shown only after [ConnectionStatus] reaches `connected`. Sends pedal and
/// dashboard events through the [ConnectionCoordinator]'s client as they
/// arrive, satisfying the PRD latency target of sub-50ms round trip.
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
  final double _steeringAngle = 0.0;
  late final PedalInput _pedalInput;
  late final DashboardInput _dashboardInput;
  late final LifecycleObserver _lifecycleObserver;
  List<DeviceOrientation>? _previousOrientations;
  bool _awaitingCalibration = false;

  @override
  void initState() {
    super.initState();

    _lifecycleObserver = LifecycleObserver(
      coordinator: widget.coordinator,
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _lockOrientation();
    _hideSystemUI();

    _pedalInput = PedalInput();
    _pedalInput.onPressureChanged(_onPedalChanged);

    _dashboardInput = DashboardInput();
    _dashboardInput.onControlActivated((control, action) {
      widget.coordinator.client.sendButtonEvent(control, action);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _restoreOrientation();
    _restoreSystemUI();
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

  void _onPedalChanged(PedalType pedal, double pressure) {
    if (_awaitingCalibration) return;

    widget.coordinator.client.sendState(
      steering: _steeringAngle,
      accelerator: _pedalInput.pressureOf(PedalType.accelerator),
      brake: _pedalInput.pressureOf(PedalType.brake),
      clutch: _pedalInput.pressureOf(PedalType.clutch),
    );
  }

  void _onCalibrationConfirmed() async {
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
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: Center(child: WheelView(angle: _steeringAngle)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 300,
              child: PedalPanel(input: _pedalInput),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 400,
              child: DashboardPanel(input: _dashboardInput),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
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
