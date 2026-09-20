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

    test('comfort and chat batch reads the keyboard map', () {
      expect(
        GamePreset.ets2.bindingFor(ControlId.driverWindowUp, false),
        'Right Shift',
      );
      expect(
        GamePreset.ets2.bindingFor(ControlId.navigationZoomIn, false),
        '/',
      );
      expect(
        GamePreset.ets2.bindingFor(ControlId.overlayActivation, false),
        'Tab',
      );
      expect(GamePreset.ets2.bindingFor(ControlId.pushToTalk, false), 'X');
    });

    test('cameras and menu batch reads the keyboard map', () {
      expect(GamePreset.ets2.bindingFor(ControlId.cameraInterior, false), '1');
      expect(GamePreset.ets2.bindingFor(ControlId.cameraLeanout, false), '5');
      expect(GamePreset.ets2.bindingFor(ControlId.dashboardInfo, false), 'I');
      expect(GamePreset.ets2.bindingFor(ControlId.nextCamera, false), '9');
      expect(GamePreset.ets2.bindingFor(ControlId.menu, false), 'Escape');
      expect(GamePreset.ets2.bindingFor(ControlId.worldMap, false), 'M');
      expect(GamePreset.ets2.bindingFor(ControlId.photoMode, false), '=');
      expect(GamePreset.ets2.bindingFor(ControlId.activate, false), 'Enter');
    });

    test('audio row keys replace the inert defaults', () {
      expect(GamePreset.ets2.bindingFor(ControlId.audioVolumeDown, false), 'L');
      expect(GamePreset.ets2.bindingFor(ControlId.audioPrevious, false), 'J');
      expect(GamePreset.ets2.bindingFor(ControlId.audioPlayPause, false), 'K');
      expect(GamePreset.ets2.bindingFor(ControlId.audioNext, false), 'U');
      expect(GamePreset.ets2.bindingFor(ControlId.audioVolumeUp, false), 'O');
    });

    test('batch controls fall back to keyboard in gamepad mode', () {
      expect(
        GamePreset.ets2.bindingFor(ControlId.driverWindowUp, true),
        'Right Shift',
      );
      expect(GamePreset.ets2.bindingFor(ControlId.chatActivation, true), 'Y');
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
