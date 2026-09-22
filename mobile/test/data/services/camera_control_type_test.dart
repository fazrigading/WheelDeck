import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/settings_repository.dart';
import 'package:wheeldeck/data/services/camera_control_type.dart';
import 'package:wheeldeck/data/services/camera_pad_mode.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/wheeldeck_client.dart';
import 'package:wheeldeck/ui/core/connection_coordinator.dart';
import 'package:wheeldeck/ui/features/driving/views/camera_pad.dart';
import 'package:wheeldeck/ui/features/driving/views/dashboard_panel.dart';
import 'package:wheeldeck/ui/features/settings/view_models/settings_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('TASK-039 fallback is dpad, unknown wire values included', () {
    expect(CameraControlType.fallback, CameraControlType.dpad);
    expect(CameraControlType.fromWireValue(null), CameraControlType.dpad);
    expect(
      CameraControlType.fromWireValue('semianalog'),
      CameraControlType.dpad,
    );
    expect(
      CameraControlType.fromWireValue('simple'),
      CameraControlType.simple,
    );
    expect(
      CameraControlType.values.map((t) => t.wireValue),
      ['dpad', 'simple', 'analog'],
    );
  });

  test('TEST-012 type persists across a reload', () async {
    await CameraControlType.analog.save();
    expect(await CameraControlType.load(), CameraControlType.analog);
  });

  test('TEST-012 reset-to-defaults restores dpad', () async {
    final coordinator = ConnectionCoordinator(deviceId: 'test');
    addTearDown(coordinator.dispose);
    final viewModel = SettingsViewModel(
      settingsRepository: const SettingsRepository(),
      connectionRepository: ConnectionRepository(
        client: WheelDeckClient(deviceId: 'test'),
      ),
    );
    addTearDown(viewModel.dispose);
    await viewModel.init();

    await viewModel.selectCameraControlType(CameraControlType.analog);
    expect(viewModel.cameraControlType, CameraControlType.analog);

    await viewModel.resetToDefaults();
    expect(viewModel.cameraControlType, CameraControlType.dpad);
    expect(await CameraControlType.load(), CameraControlType.dpad);
  });

  testWidgets('TASK-041 dpad branch renders, other types await shapes', (
    tester,
  ) async {
    final input = DashboardInput();
    final events = <(ControlId, ActionType)>[];
    input.onControlActivated((control, action) => events.add((control, action)));
    Widget pad(CameraControlType type) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: CameraPad(
            mode: CameraPadMode.numpad,
            input: input,
            bindingFor: (_) => 'K',
            onModeSwitch: () {},
            controlType: type,
          ),
        ),
      ),
    );

    await tester.pumpWidget(pad(CameraControlType.dpad));
    expect(find.byKey(const ValueKey('camera-pad-center')), findsOneWidget);

    await tester.pumpWidget(pad(CameraControlType.simple));
    expect(find.byKey(const ValueKey('camera-pad-center')), findsNothing);
  });

  testWidgets('TEST-011 simple taps emit divide, recenter, multiply', (
    tester,
  ) async {
    final input = DashboardInput();
    final events = <(ControlId, ActionType)>[];
    input.onControlActivated((control, action) => events.add((control, action)));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CameraPad(
              mode: CameraPadMode.numpad,
              input: input,
              bindingFor: (_) => 'K',
              onModeSwitch: () {},
              controlType: CameraControlType.simple,
            ),
          ),
        ),
      ),
    );

    // Three 3x1 buttons fill the 3x3 region.
    expect(find.byType(DashboardControl), findsNWidgets(3));

    await tester.tap(
      find.byKey(const ValueKey('camera-simple-cameraSimpleLeft')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('camera-simple-cameraPadRecenter')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('camera-simple-cameraSimpleRight')),
    );
    await tester.pump();

    expect(events.map((e) => e.$1).toSet(), {
      ControlId.cameraSimpleLeft,
      ControlId.cameraPadRecenter,
      ControlId.cameraSimpleRight,
    });
  });
}
