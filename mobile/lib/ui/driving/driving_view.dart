import 'package:flutter/material.dart';

import '../../input/dashboard_input.dart';
import '../../input/pedal_input.dart';
import '../dashboard/dashboard_panel.dart';
import '../pedals/pedal_panel.dart';
import '../wheel/wheel_view.dart';
import '../../state/connection_coordinator.dart';

/// The post-connection driving view: steering wheel, pedal bars, and dashboard
/// controls in a single-column layout.
///
/// Shown only after [ConnectionStatus] reaches `connected`. Sends pedal and
/// dashboard events through the [ConnectionCoordinator]'s client as they
/// arrive, satisfying the PRD latency target of sub-50ms round trip.
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

  @override
  void initState() {
    super.initState();

    _pedalInput = PedalInput();
    _pedalInput.onPressureChanged(_onPedalChanged);

    _dashboardInput = DashboardInput();
    _dashboardInput.onControlActivated((control, action) {
      widget.coordinator.client.sendButtonEvent(control, action);
    });
  }

  @override
  void dispose() {
    _pedalInput.dispose();
    super.dispose();
  }

  void _onPedalChanged(PedalType pedal, double pressure) {
    widget.coordinator.client.sendState(
      steering: _steeringAngle,
      accelerator: _pedalInput.pressureOf(PedalType.accelerator),
      brake: _pedalInput.pressureOf(PedalType.brake),
      clutch: _pedalInput.pressureOf(PedalType.clutch),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_off),
            onPressed: widget.coordinator.disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
        ),
      ),
    );
  }
}
