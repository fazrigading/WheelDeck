import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/settings_repository.dart';
import 'package:wheeldeck/data/services/wheeldeck_client.dart';
import 'package:wheeldeck/ui/core/connection_coordinator.dart';
import 'package:wheeldeck/ui/features/settings/view_models/settings_view_model.dart';
import 'package:wheeldeck/ui/features/settings/views/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionCoordinator coordinator;

  setUp(() {
    coordinator = ConnectionCoordinator(deviceId: 'test');
    addTearDown(coordinator.dispose);
  });

  Future<void> pumpScreen(WidgetTester tester, String wheelMode) async {
    // A tall viewport so the mid-list sections build despite the ListView's
    // lazy construction.
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'wheeldeck.wheel_mode': wheelMode});

    final viewModel = SettingsViewModel(
      settingsRepository: const SettingsRepository(),
      connectionRepository: ConnectionRepository(
        client: WheelDeckClient(deviceId: 'test'),
      ),
    );
    addTearDown(viewModel.dispose);
    await viewModel.init();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(coordinator: coordinator, viewModel: viewModel),
      ),
    );
    await tester.pump();
  }

  testWidgets('gyro mode shows pedal sides, dashboard controls, and the '
      'dashboard switch', (tester) async {
    await pumpScreen(tester, 'gyro');

    expect(find.text('Pedal sides'), findsOneWidget);
    expect(find.text('Dashboard controls'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Clutch pedal'), findsOneWidget);
  });

  testWidgets('rotatable mode hides pedal sides and dashboard sections but '
      'keeps the clutch switch', (tester) async {
    await pumpScreen(tester, 'rotatable');

    expect(find.text('Pedal sides'), findsNothing);
    expect(find.text('Dashboard controls'), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Clutch pedal'), findsOneWidget);
  });
}
