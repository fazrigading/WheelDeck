import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/repositories/pedal_repository.dart';
import '../../../../data/repositories/sensor_repository.dart';
import '../../../../data/services/gyroscope_service.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/pedal_input.dart';
import '../../../../data/services/steering_sensor.dart';
import '../../../../ui/core/connection_coordinator.dart';
import '../../../../ui/core/lifecycle_observer.dart';
import '../../settings/views/settings_screen.dart';
import '../view_models/driving_view_model.dart';
import 'calibration_overlay.dart';
import 'dashboard_panel.dart';
import 'pedal_panel.dart';
import 'wheel_view.dart';

/// The post-connection driving view: steering wheel, pedal bars, and dashboard
/// controls in a landscape row layout.
///
/// Shown only after the connection reaches `connected`. Lean widget: all input
/// state lives in [DrivingViewModel] and the body rebuilds via
/// `ListenableBuilder`. Sends pedal and dashboard events through the
/// coordinator's connection repository as they arrive, satisfying the PRD
/// latency target of sub-50ms round trip.
///
/// Pauses input and disconnects on lifecycle interruptions (call, screen lock,
/// backgrounding). On resume, the user must re-confirm steering calibration
/// before input resumes.
class DrivingView extends StatefulWidget {
  const DrivingView({super.key, required this.coordinator, this.viewModel});

  final ConnectionCoordinator coordinator;

  /// Override for tests. When omitted, the state builds a live view model
  /// from the coordinator's connection repository and the platform gyroscope.
  final DrivingViewModel? viewModel;

  @override
  State<DrivingView> createState() => _DrivingViewState();
}

class _DrivingViewState extends State<DrivingView> {
  late final DrivingViewModel _viewModel;
  late final bool _ownsViewModel;
  late final LifecycleObserver _lifecycleObserver;
  List<DeviceOrientation>? _previousOrientations;

  @override
  void initState() {
    super.initState();

    _lifecycleObserver = LifecycleObserver(
      coordinator: widget.coordinator,
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);

    _lockOrientation();
    _hideSystemUI();

    final override = widget.viewModel;
    if (override != null) {
      _viewModel = override;
      _ownsViewModel = false;
    } else {
      _viewModel = DrivingViewModel(
        connectionRepository: widget.coordinator.connectionRepository,
        sensorRepository: SensorRepository(
          sensor: SteeringSensor(
            rawAngleStream: GyroscopeService().rawAngles,
          ),
        ),
        pedalRepository: PedalRepository(input: PedalInput()),
        dashboardInput: DashboardInput(),
        initialAwaitingCalibration: widget.coordinator.isPaused,
      );
      _ownsViewModel = true;
      _viewModel.init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _restoreOrientation();
    _restoreSystemUI();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DrivingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _viewModel.setAwaitingCalibration(widget.coordinator.isPaused);
  }

  Future<void> _onCalibrationConfirmed() async {
    _viewModel.confirmCalibration();

    final target = _viewModel.lastTarget;
    if (target != null) {
      await widget.coordinator.connect(target);
    }
  }

  Future<void> _onDisconnect() => _viewModel.disconnect();

  void _onRecalibrate() {
    _viewModel.recalibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Steering re-centered'), duration: Duration(seconds: 1)),
    );
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
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final calibrating = _viewModel.awaitingCalibration;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Driving'),
            actions: [
              if (!calibrating)
                IconButton(
                  key: const Key('recalibrate-button'),
                  icon: const Icon(Icons.center_focus_strong),
                  onPressed: _onRecalibrate,
                  tooltip: 'Recalibrate',
                ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(coordinator: widget.coordinator),
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
          floatingActionButton: calibrating
              ? null
              : FloatingActionButton.small(
                  key: const Key('recalibrate-fab'),
                  onPressed: _onRecalibrate,
                  tooltip: 'Recalibrate',
                  child: const Icon(Icons.center_focus_strong),
                ),
          body: SafeArea(
            child: calibrating
                ? CalibrationOverlay(
                    angle: _viewModel.steering.angle,
                    onConfirmed: _onCalibrationConfirmed,
                  )
                : _buildDrivingContent(),
          ),
        );
      },
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
                  onHorizontalDragStart: (_) =>
                      _viewModel.onWheelDragStart(),
                  onHorizontalDragUpdate: (details) =>
                      _viewModel.onWheelDragUpdate(details.delta.dx),
                  onHorizontalDragEnd: (_) => _viewModel.onWheelDragEnd(),
                  onDoubleTap: () => _viewModel.onWheelDragEnd(),
                  child: WheelView(
                    angle: _viewModel.steering.angle,
                    size: wheelSize,
                  ),
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
                      child: PedalPanel(
                        input: _viewModel.pedalInput,
                        layout: _viewModel.pedalLayout.order,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child:
                            DashboardPanel(input: _viewModel.dashboardInput),
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
