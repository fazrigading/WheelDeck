import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/controller_preset.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';

void main() {
  group('GamePreset.bindingFor', () {
    test('keyboard mode reads the keyboard map', () {
      expect(
        GamePreset.ets2.bindingFor(ControlId.parkingBrake, false),
        'Space',
      );
      expect(GamePreset.ets2.bindingFor(ControlId.gearUp, false), 'Left Shift');
    });

    test('gamepad mode reads the gamepad map', () {
      expect(GamePreset.ets2.bindingFor(ControlId.parkingBrake, true), 'A');
      expect(GamePreset.ets2.bindingFor(ControlId.hazardLights, true), 'Back');
      expect(GamePreset.ets2.bindingFor(ControlId.gearUp, true), 'DPadUp');
    });

    test(
      'gamepad mode falls back to the keyboard map for missing controls',
      () {
        expect(GamePreset.ets2.bindingFor(ControlId.beaconLights, true), 'O');
        expect(GamePreset.ets2.bindingFor(ControlId.flasher, true), 'J');
        expect(GamePreset.ets2.bindingFor(ControlId.liftDropAxle, true), 'U');
        expect(GamePreset.ets2.bindingFor(ControlId.garageManager, true), 'G');
      },
    );

    test('controls missing from both maps stay unbound', () {
      expect(GamePreset.ets2.bindingFor(ControlId.audioFavorite, true), '-');
      expect(GamePreset.ets2.bindingFor(ControlId.audioFavorite, false), '-');
    });
  });
}
