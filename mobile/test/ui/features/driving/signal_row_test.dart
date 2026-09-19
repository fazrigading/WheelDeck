import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/pedal_repository.dart';
import 'package:wheeldeck/data/repositories/sensor_repository.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';
import 'package:wheeldeck/data/services/steering_sensor.dart';
import 'package:wheeldeck/data/services/wheeldeck_client.dart';
import 'package:wheeldeck/ui/core/connection_coordinator.dart';
import 'package:wheeldeck/ui/features/driving/view_models/driving_view_model.dart';
import 'package:wheeldeck/ui/features/driving/views/dashboard_panel.dart';
import 'package:wheeldeck/ui/features/driving/views/driving_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionCoordinator coordinator;

  setUp(() {
    coordinator = ConnectionCoordinator(deviceId: 'test');
    addTearDown(coordinator.dispose);
  });

  /// Pumps the driving view with [prefs] (mock initial values) at the
  /// reference resolution; returns the view model.
  Future<DrivingViewModel> pumpView(
    WidgetTester tester,
    Map<String, Object> prefs,
  ) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(prefs);

    final viewModel = DrivingViewModel(
      connectionRepository: ConnectionRepository(
        client: WheelDeckClient(deviceId: 'test'),
      ),
      sensorRepository: SensorRepository(
        sensor: SteeringSensor(rawAngleStream: const Stream.empty()),
      ),
      pedalRepository: PedalRepository(input: PedalInput()),
      dashboardInput: DashboardInput(),
    );
    addTearDown(viewModel.dispose);
    await viewModel.init();

    await tester.pumpWidget(
      MaterialApp(
        home: DrivingView(coordinator: coordinator, viewModel: viewModel),
      ),
    );
    await tester.pump();
    return viewModel;
  }

  Finder signalCell(ControlId control) =>
      find.byKey(ValueKey('dashboard-${control.name}'));

  int signalCellCount(WidgetTester tester) => tester
      .widgetList<DashboardControl>(
        find.byWidgetPredicate(
          (w) =>
              w is DashboardControl &&
              (w.control == ControlId.turnSignalLeft ||
                  w.control == ControlId.turnSignalRight),
        ),
      )
      .length;

  const gyroHidden = {
    'wheeldeck.wheel_mode': 'gyro',
    'wheeldeck.show_dashboard': false,
    // Put the brake on the left so the row sits above a real pedal bar.
    'wheeldeck.pedal_side.brake': 'left',
  };
  const gyroShown = {
    'wheeldeck.wheel_mode': 'gyro',
    'wheeldeck.show_dashboard': true,
    'wheeldeck.pedal_side.brake': 'left',
  };

  testWidgets('gyro with dashboard hidden renders two signal cells above '
      'the left pedal column', (tester) async {
    await pumpView(tester, gyroHidden);

    expect(signalCell(ControlId.turnSignalLeft), findsOneWidget);
    expect(signalCell(ControlId.turnSignalRight), findsOneWidget);
    expect(signalCellCount(tester), 2);

    // Above the left pedal column: the signal cells' bottom sits above the
    // brake bar's top.
    final cellBottom = tester
        .getBottomRight(signalCell(ControlId.turnSignalLeft))
        .dy;
    final brakeTop = tester
        .getTopLeft(find.byKey(const ValueKey('pedal-brake')))
        .dy;
    expect(cellBottom, lessThan(brakeTop));
  });

  testWidgets('gyro with dashboard shown renders them in the same position '
      'with no duplicates', (tester) async {
    await pumpView(tester, gyroHidden);
    final hiddenRect = tester.getRect(signalCell(ControlId.turnSignalLeft));

    await pumpView(tester, gyroShown);
    final shownRect = tester.getRect(signalCell(ControlId.turnSignalLeft));

    expect(signalCell(ControlId.turnSignalLeft), findsOneWidget);
    expect(signalCell(ControlId.turnSignalRight), findsOneWidget);
    expect(signalCellCount(tester), 2);

    // The dashboard wrap must not move the row between states.
    expect(shownRect, hiddenRect);
  });

  testWidgets('rotatable renders the signals as top-left block A cells', (
    tester,
  ) async {
    await pumpView(tester, {'wheeldeck.wheel_mode': 'rotatable'});

    expect(signalCell(ControlId.turnSignalLeft), findsOneWidget);
    expect(signalCell(ControlId.turnSignalRight), findsOneWidget);
    expect(signalCellCount(tester), 2);

    // Block A occupies rows 1-4, cols 1-5 of the global 8x15 grid: at the
    // 2400x1080 reference, x < 800 and y < 540.
    final center = tester.getCenter(signalCell(ControlId.turnSignalLeft));
    expect(center.dx, lessThan(800));
    expect(center.dy, lessThan(540));
  });

  testWidgets('rotatable renders blocks B, C, and E regardless of '
      'showDashboard', (tester) async {
    await pumpView(tester, {
      'wheeldeck.wheel_mode': 'rotatable',
      'wheeldeck.show_dashboard': false,
    });

    // Block B audio, block C gears, block E services — the rotatable grid
    // ignores the dashboard preference (REQ-019).
    expect(signalCell(ControlId.audioPlayPause), findsOneWidget);
    expect(signalCell(ControlId.gearUp), findsOneWidget);
    expect(signalCell(ControlId.quickSave), findsOneWidget);
  });
}
