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
import 'package:wheeldeck/ui/features/connection/views/connection_screen.dart';
import 'package:wheeldeck/ui/features/driving/view_models/driving_view_model.dart';
import 'package:wheeldeck/ui/features/driving/views/driving_view.dart';
import 'package:wheeldeck/ui/features/settings/views/settings_screen.dart';

/// Driving view model that records exit-related calls without touching the
/// connection layer, so dialog behavior is observable at the widget seam.
class _SpyViewModel extends DrivingViewModel {
  _SpyViewModel({
    required super.connectionRepository,
    required super.sensorRepository,
    required super.pedalRepository,
    required super.dashboardInput,
  });

  int refreshCount = 0;
  int disconnectCount = 0;

  @override
  Future<void> refreshSettings() async => refreshCount++;

  @override
  Future<void> disconnect() async => disconnectCount++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionCoordinator coordinator;
  late _SpyViewModel viewModel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'wheeldeck.wheel_mode': 'gyro'});
    coordinator = ConnectionCoordinator(deviceId: 'test');
    addTearDown(coordinator.dispose);
    viewModel = _SpyViewModel(
      connectionRepository: ConnectionRepository(
        client: WheelDeckClient(deviceId: 'test'),
      ),
      sensorRepository: SensorRepository(
        sensor: SteeringSensor(rawAngleStream: const Stream.empty()),
      ),
      pedalRepository: PedalRepository(input: PedalInput()),
      dashboardInput: DashboardInput(),
    );
    await viewModel.init();
    addTearDown(viewModel.dispose);
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DrivingView(coordinator: coordinator, viewModel: viewModel),
      ),
    );
    await tester.pump();
  }

  Future<void> pressSystemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('top bar is gone and recalibrate stays on the FAB', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('recalibrate-fab')), findsOneWidget);
  });

  testWidgets(
    'back-press opens the exit dialog; Stay dismisses with no side effects',
    (tester) async {
      await pumpView(tester);

      await pressSystemBack(tester);

      expect(find.text('Exit driving?'), findsOneWidget);
      expect(find.byKey(const Key('exit-settings')), findsOneWidget);
      expect(find.byKey(const Key('exit-disconnect')), findsOneWidget);
      expect(find.byKey(const Key('exit-stay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exit-stay')));
      await tester.pumpAndSettle();

      expect(find.text('Exit driving?'), findsNothing);
      expect(find.byType(DrivingView), findsOneWidget);
      expect(find.byType(ConnectionScreen), findsNothing);
      expect(viewModel.disconnectCount, 0);
      expect(viewModel.refreshCount, 0);
    },
  );

  testWidgets('Settings action pushes settings and refreshes on return', (
    tester,
  ) async {
    await pumpView(tester);

    await pressSystemBack(tester);
    await tester.tap(find.byKey(const Key('exit-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(DrivingView), findsOneWidget);
    expect(viewModel.refreshCount, 1);
    expect(viewModel.disconnectCount, 0);
  });

  testWidgets(
    'Disconnect action disconnects without pushing the connection screen',
    (tester) async {
      await pumpView(tester);
      // An outstanding lifecycle pause must not keep the driving view mounted
      // after disconnect; the dialog's Disconnect clears it so routing lands
      // on app home.
      await coordinator.pause();

      await pressSystemBack(tester);
      await tester.tap(find.byKey(const Key('exit-disconnect')));
      await tester.pumpAndSettle();

      expect(viewModel.disconnectCount, 1);
      expect(coordinator.isPaused, isFalse);
      expect(find.byType(ConnectionScreen), findsNothing);
    },
  );
}
