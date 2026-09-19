import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/repositories/pedal_repository.dart';
import '../../../../data/repositories/sensor_repository.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/driving_layout.dart';
import '../../../../data/services/input_mapping.dart';
import '../../../../data/services/pedal_side.dart';
import '../../../../data/services/gyroscope_service.dart';
import '../../../../data/services/pedal_input.dart';
import '../../../../data/services/steering_sensor.dart';
import '../../../../ui/core/connection_coordinator.dart';
import '../../../../ui/core/lifecycle_observer.dart';
import '../../settings/views/binding_edit_dialog.dart';
import '../../settings/views/settings_screen.dart';
import '../view_models/driving_view_model.dart';
import 'block_grid.dart';
import 'calibration_overlay.dart';
import 'dashboard_panel.dart';
import 'pedal_panel.dart';
import 'signal_arrows.dart';
import 'tilt_readout.dart';
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
/// backgrounding). On resume in gyro mode, the user must re-confirm steering
/// calibration before input resumes; rotatable mode resumes directly.
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

    _lifecycleObserver = LifecycleObserver(coordinator: widget.coordinator);
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
          sensor: SteeringSensor(rawAngleStream: GyroscopeService().rawAngles),
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

  /// Intercepts the system back gesture: driving is the navigator root, so a
  /// back-press must ask instead of leaving or killing the app.
  Future<void> _confirmExit() async {
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit driving?'),
        content: const Text('Change settings, or disconnect from the desktop.'),
        actions: [
          TextButton(
            key: const Key('exit-settings'),
            onPressed: () => Navigator.of(context).pop(_ExitAction.settings),
            child: const Text('Settings'),
          ),
          TextButton(
            key: const Key('exit-disconnect'),
            onPressed: () => Navigator.of(context).pop(_ExitAction.disconnect),
            child: const Text('Disconnect'),
          ),
          TextButton(
            key: const Key('exit-stay'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;

    if (action == _ExitAction.settings) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(coordinator: widget.coordinator),
        ),
      );
      if (!mounted) return;
      await _viewModel.refreshSettings();
      return;
    }

    // resume() clears an outstanding lifecycle pause so _Routing lands on
    // Menu (app home) even when Disconnect is tapped mid-pause; _Routing then
    // switches on the disconnected status. No extra route is pushed.
    widget.coordinator.resume();
    await _viewModel.disconnect();
  }

  void _onRecalibrate() {
    HapticFeedback.lightImpact();
    _viewModel.recalibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Steering re-centered'),
        duration: Duration(seconds: 1),
      ),
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
        // Rotatable steering cannot drift: no calibration gate, no recentering.
        final rotatable = _viewModel.isRotatable;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmExit();
          },
          child: Scaffold(
            floatingActionButton: calibrating || rotatable
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
          ),
        );
      },
    );
  }

  Widget _buildDrivingContent() {
    final vis = _viewModel.visibility;
    final sides = _viewModel.pedalSides;
    final shown = [
      PedalType.accelerator,
      PedalType.brake,
      if (vis.showClutch) PedalType.clutch,
    ];

    if (_viewModel.isRotatable) {
      return _rotatableLayout(shown.toSet());
    }

    final left = shown.where((p) => sides[p] == PedalSide.left).toList();
    final right = shown.where((p) => sides[p] != PedalSide.left).toList();
    return _gyroLayout(left, right, vis.showDashboard);
  }

  /// Rotatable: the Sequential preset rendered through the block grid —
  /// wheel, pedals, signals, and dashboard cells all come from the layout
  /// slots. Brake and accelerator are fixed; the clutch follows its settings
  /// toggle.
  Widget _rotatableLayout(Set<PedalType> shownPedals) {
    return BlockGrid(
      layout: DrivingLayout.sequential(),
      input: _viewModel.dashboardInput,
      bindingFor: _viewModel.bindingFor,
      gate: _viewModel.sendGate,
      pedalInput: _viewModel.pedalInput,
      shownPedals: shownPedals,
      degrees: _viewModel.rotationDegree,
      onSteering: _viewModel.setRotatableSteering,
      onBindRequested: _openBinder,
    );
  }

  /// Shared grid: core controls plus visible extras. Turn signals never
  /// appear here; [SignalArrows] owns them.
  DashboardPanel _grid({Set<ControlId> excluded = const {}}) => DashboardPanel(
    input: _viewModel.dashboardInput,
    bindingFor: _viewModel.bindingFor,
    gate: _viewModel.sendGate,
    visibleExtras: _viewModel.visibleExtras,
    excluded: excluded,
    engineStartMode: _viewModel.engineStartMode,
    onBindRequested: _openBinder,
  );

  Future<void> _openBinder(ControlId control) async {
    await BindingEditDialog.show(
      context,
      title: DashboardPanel.gridLabel(control),
      current: _viewModel.bindingFor(control),
      isGamepad: _viewModel.mapping == InputMapping.gamepad,
      onSave: (value) => _viewModel.setBinding(control, value),
    );
    await _viewModel.refreshSettings();
  }

  SignalArrows get _arrows =>
      SignalArrows(input: _viewModel.dashboardInput, gate: _viewModel.sendGate);

  /// Gyro: dashboard hidden shows wheel middle with tilt readout beneath;
  /// dashboard shown drops the wheel for a top-center tilt readout. Arrows
  /// sit above the left pedal; pedals follow their per-pedal sides.
  Widget _gyroLayout(
    List<PedalType> left,
    List<PedalType> right,
    bool dashboardVisible,
  ) {
    Widget pedalColumn(List<PedalType> pedals, {bool arrows = false}) {
      return Expanded(
        child: Column(
          children: [
            if (arrows)
              Padding(padding: const EdgeInsets.all(8), child: _arrows),
            if (pedals.isNotEmpty)
              Expanded(
                child: PedalPanel(input: _viewModel.pedalInput, layout: pedals),
              ),
          ],
        ),
      );
    }

    if (!dashboardVisible) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pedalColumn(left, arrows: true),
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onHorizontalDragStart: (_) => _viewModel.onWheelDragStart(),
                    onHorizontalDragUpdate: (details) =>
                        _viewModel.onWheelDragUpdate(details.delta.dx),
                    onHorizontalDragEnd: (_) => _viewModel.onWheelDragEnd(),
                    onDoubleTap: () => _viewModel.onWheelDragEnd(),
                    child: WheelView(
                      angle: _viewModel.steering.angle,
                      size: 220,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TiltReadout(angle: _viewModel.steering.angle),
                ],
              ),
            ),
          ),
          pedalColumn(right),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: TiltReadout(angle: _viewModel.steering.angle)),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pedalColumn(left, arrows: true),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: _grid(),
                ),
              ),
              pedalColumn(right),
            ],
          ),
        ),
      ],
    );
  }
}

/// The dialog actions that trigger behavior; Stay and barrier dismissal pop
/// with null.
enum _ExitAction { settings, disconnect }
