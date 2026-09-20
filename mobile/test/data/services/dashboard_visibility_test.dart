import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/dashboard_visibility.dart';
import 'package:wheeldeck/data/services/engine_start_mode.dart';
import 'package:wheeldeck/ui/features/driving/views/dashboard_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EngineStartMode', () {
    test('defaults to hold-confirm', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await EngineStartMode.load(), EngineStartMode.holdConfirm);
    });

    test('round-trips single press', () async {
      SharedPreferences.setMockInitialValues({});
      await EngineStartMode.singlePress.save();
      expect(await EngineStartMode.load(), EngineStartMode.singlePress);
    });

    test('unknown value falls back to hold-confirm', () {
      expect(EngineStartMode.fromWireValue('bogus'), EngineStartMode.holdConfirm);
    });
  });

  group('DashboardVisibility', () {
    test('defaults show gears and engine brake only', () {
      expect(
        DashboardVisibility.defaults,
        {ControlId.gearUp, ControlId.gearDown, ControlId.engineBrake},
      );
    });

    test('defaults load from empty prefs', () async {
      SharedPreferences.setMockInitialValues({});
      expect((await DashboardVisibility.load()).visibleExtras,
          DashboardVisibility.defaults);
    });

    test('toggle round-trips through prefs', () async {
      SharedPreferences.setMockInitialValues({});
      var visibility = await DashboardVisibility.load();
      visibility = visibility.toggled(ControlId.airHorn);
      expect(visibility.isVisible(ControlId.airHorn), isTrue);
      await visibility.save();

      final reloaded = await DashboardVisibility.load();
      expect(reloaded.isVisible(ControlId.airHorn), isTrue);
      expect(reloaded.isVisible(ControlId.gearUp), isTrue);
    });

    test('toggle twice restores the default set', () async {
      SharedPreferences.setMockInitialValues({});
      final visibility = (await DashboardVisibility.load())
          .toggled(ControlId.airHorn)
          .toggled(ControlId.airHorn);
      expect(visibility.visibleExtras, DashboardVisibility.defaults);
    });

    test('core grid controls are never toggleable extras', () {
      for (final control in DashboardVisibility.toggleable) {
        expect(DashboardPanel.coreControls.contains(control), isFalse,
            reason: control.name);
      }
    });

    test('block E split: dashboard info and activate are toggleable, the '
        'camera and menu controls are not (TASK-049)', () {
      expect(DashboardVisibility.toggleable.contains(ControlId.dashboardInfo),
          isTrue);
      expect(DashboardVisibility.toggleable.contains(ControlId.activate),
          isTrue);
      const excluded = [
        ControlId.cameraInterior,
        ControlId.cameraChasing,
        ControlId.cameraTopdown,
        ControlId.cameraRoof,
        ControlId.cameraLeanout,
        ControlId.nextCamera,
        ControlId.menu,
        ControlId.worldMap,
        ControlId.photoMode,
      ];
      for (final control in excluded) {
        expect(DashboardVisibility.toggleable.contains(control), isFalse,
            reason: control.name);
      }
    });

    test('comfort and chat batch is toggleable (TASK-049)', () {
      const batch = [
        ControlId.driverWindowUp,
        ControlId.driverWindowDown,
        ControlId.passengerWindowUp,
        ControlId.passengerWindowDown,
        ControlId.navigationZoomIn,
        ControlId.overlayActivation,
        ControlId.chatActivation,
        ControlId.quickReplies,
        ControlId.nameTags,
        ControlId.pushToTalk,
      ];
      for (final control in batch) {
        expect(DashboardVisibility.toggleable.contains(control), isTrue,
            reason: control.name);
      }
    });
  });
}
