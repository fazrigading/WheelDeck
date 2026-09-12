import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/services/controller_visibility.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';
import 'package:wheeldeck/data/services/pedal_side.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ControllerVisibility', () {
    test('fresh install defaults: clutch hidden, dashboard shown', () async {
      SharedPreferences.setMockInitialValues({});
      final v = await ControllerVisibility.load();
      expect(v.showClutch, isFalse);
      expect(v.showDashboard, isTrue);
    });

    test('migrates legacy full to all-ON and deletes old key', () async {
      SharedPreferences.setMockInitialValues(
          {'wheeldeck.controller_type': 'full'});
      final v = await ControllerVisibility.load();
      expect(v.showClutch, isTrue);
      expect(v.showDashboard, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wheeldeck.controller_type'), isNull);
    });

    test('migrates legacy steeringOnly to both OFF', () async {
      SharedPreferences.setMockInitialValues(
          {'wheeldeck.controller_type': 'steeringOnly'});
      final v = await ControllerVisibility.load();
      expect(v.showClutch, isFalse);
      expect(v.showDashboard, isFalse);
    });

    test('migrates every legacy preset', () async {
      const cases = {
        'steeringOnly': (false, false),
        'steering2Pedals': (false, false),
        'steering3Pedals': (true, false),
        'steeringDashboard': (false, true),
        'full': (true, true),
      };
      for (final entry in cases.entries) {
        SharedPreferences.setMockInitialValues(
            {'wheeldeck.controller_type': entry.key});
        final v = await ControllerVisibility.load();
        expect(v.showClutch, entry.value.$1, reason: entry.key);
        expect(v.showDashboard, entry.value.$2, reason: entry.key);
        // migrated values persist under new keys
        final again = await ControllerVisibility.load();
        expect(again.showClutch, entry.value.$1, reason: entry.key);
        expect(again.showDashboard, entry.value.$2, reason: entry.key);
      }
    });

    test('round-trips explicit values', () async {
      SharedPreferences.setMockInitialValues({});
      await const ControllerVisibility(showClutch: true, showDashboard: false)
          .save();
      final v = await ControllerVisibility.load();
      expect(v.showClutch, isTrue);
      expect(v.showDashboard, isFalse);
    });
  });

  group('PedalSides', () {
    test('fresh install defaults: Acc-R Brake-R Clutch-L', () async {
      SharedPreferences.setMockInitialValues({});
      final sides = await PedalSides.load();
      expect(sides.sideOf(PedalType.accelerator), PedalSide.right);
      expect(sides.sideOf(PedalType.brake), PedalSide.right);
      expect(sides.sideOf(PedalType.clutch), PedalSide.left);
    });

    test('migrates legacy layoutB and deletes old key', () async {
      SharedPreferences.setMockInitialValues(
          {'wheeldeck.pedal_layout': 'layoutB'});
      final sides = await PedalSides.load();
      expect(sides.sideOf(PedalType.accelerator), PedalSide.right);
      expect(sides.sideOf(PedalType.brake), PedalSide.left);
      expect(sides.sideOf(PedalType.clutch), PedalSide.left);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wheeldeck.pedal_layout'), isNull);
    });

    test('migrates every legacy layout', () async {
      const cases = {
        'layoutA': ('right', 'right', 'left'),
        'layoutB': ('right', 'left', 'left'),
        'layoutC': ('right', 'right', 'left'),
        'layoutD': ('right', 'left', 'left'),
      };
      for (final entry in cases.entries) {
        SharedPreferences.setMockInitialValues(
            {'wheeldeck.pedal_layout': entry.key});
        final sides = await PedalSides.load();
        expect(sides.sideOf(PedalType.accelerator).wireValue, entry.value.$1,
            reason: entry.key);
        expect(sides.sideOf(PedalType.brake).wireValue, entry.value.$2,
            reason: entry.key);
        expect(sides.sideOf(PedalType.clutch).wireValue, entry.value.$3,
            reason: entry.key);
      }
    });

    test('round-trips explicit sides', () async {
      SharedPreferences.setMockInitialValues({});
      await PedalSides({
        PedalType.accelerator: PedalSide.left,
        PedalType.brake: PedalSide.right,
        PedalType.clutch: PedalSide.left,
      }).save();
      final sides = await PedalSides.load();
      expect(sides.sideOf(PedalType.accelerator), PedalSide.left);
    });
  });
}
