import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/repositories/pedal_repository.dart';
import '../../../../data/repositories/sensor_repository.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
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
import 'calibration_overlay.dart';
import 'dashboard_panel.dart';
import 'pedal_panel.dart';
import 'rotatable_wheel.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final vis = _viewModel.visibility;
        final sides = _viewModel.pedalSides;
        final shown = [
          PedalType.accelerator,
          PedalType.brake,
          if (vis.showClutch) PedalType.clutch,
        ];
        final left = shown.where((p) => sides[p] == PedalSide.left).toList();
        final right = shown.where((p) => sides[p] != PedalSide.left).toList();

        if (_viewModel.isRotatable) {
          return _rotatableLayout(constraints, left, right);
        }
        return _gyroLayout(left, right, vis.showDashboard);
      },
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

  /// Rotatable: bottom-left 50% wheel with arrows above, clutch top-left,
  /// pedals bottom-right, gears vertical top-right, grid center-right.
  Widget _rotatableLayout(
    BoxConstraints constraints,
    List<PedalType> left,
    List<PedalType> right,
  ) {
    final wheelSize =
        (math.min(constraints.maxWidth * 0.5, constraints.maxHeight) - 16)
            .clamp(160.0, 480.0);
    final gears = [
      ControlId.gearUp,
      ControlId.gearDown,
    ].where((c) => _viewModel.visibleExtras.contains(c)).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (left.isNotEmpty)
                Expanded(
                  child: PedalPanel(input: _viewModel.pedalInput, layout: left),
                ),
              Padding(padding: const EdgeInsets.all(8), child: _arrows),
              RotatableWheel(
                degrees: _viewModel.rotationDegree,
                size: wheelSize,
                onChanged: _viewModel.setRotatableSteering,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: _grid(excluded: gears.toSet()),
                      ),
                    ),
                    if (gears.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            for (final gear in gears)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: DashboardControl(
                                  key: ValueKey('gear-${gear.name}'),
                                  label: DashboardPanel.labelFor(gear),
                                  control: gear,
                                  input: _viewModel.dashboardInput,
                                  mode: DashboardControl.modeFor(gear),
                                  gate: _viewModel.sendGate,
                                  enabled: !DashboardSendGate.isUnbound(
                                    _viewModel.bindingFor(gear),
                                  ),
                                  onBindRequested: _openBinder,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (right.isNotEmpty)
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: PedalPanel(
                      input: _viewModel.pedalInput,
                      layout: right,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

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
