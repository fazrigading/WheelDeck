import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/settings_repository.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/data/services/layout_profile.dart';
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

  Future<void> pumpScreen(
    WidgetTester tester,
    String wheelMode, {
    Future<void> Function()? seed,
  }) async {
    // A tall viewport so the mid-list sections build despite the ListView's
    // lazy construction.
    tester.view.physicalSize = const Size(1080, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'wheeldeck.wheel_mode': wheelMode});
    if (seed != null) await seed();

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

  testWidgets('rotatable mode lists the Sequential preset as read-only', (
    tester,
  ) async {
    await pumpScreen(tester, 'rotatable');

    expect(find.text('Layout profile'), findsOneWidget);
    for (final name in const [
      'Sequential',
      'Simple Automatic',
      'Real Automatic',
      'H-Shifter',
    ]) {
      expect(
        find.byKey(ValueKey('layout-profile-$name')),
        findsOneWidget,
        reason: name,
      );
    }
    expect(
      find.text('Developer preset · read-only'),
      findsNWidgets(4),
    );
  });

  testWidgets('gyro mode hides the layout profile section', (tester) async {
    await pumpScreen(tester, 'gyro');

    expect(find.text('Layout profile'), findsNothing);
  });

  testWidgets('tapping a user profile selects it', (tester) async {
    await pumpScreen(
      tester,
      'rotatable',
      seed: () async {
        await LayoutProfileStore.saveProfile(
          const LayoutProfile(
            name: 'Mine',
            layout: DrivingLayout(
              name: 'Mine',
              slots: [
                LayoutSlot(
                  rect: CellRect(
                    rowStart: 1,
                    colStart: 1,
                    rowSpan: 1,
                    colSpan: 1,
                  ),
                  kind: SlotKind.button,
                  control: ControlId.horn,
                ),
              ],
            ),
          ),
        );
      },
    );

    expect(
      find.byKey(const ValueKey('layout-profile-Mine')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('layout-profile-Mine')));
    await tester.pump();

    expect(await LayoutProfileStore.loadActiveName(), 'Mine');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('layout-profile-Mine')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });
}
