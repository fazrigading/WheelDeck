import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/controller_preset.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/ui/features/driving/views/dashboard_panel.dart';

void main() {
  group('DashboardControl.modeFor', () {
    test('toggle-pulse controls', () {
      const toggles = [
        ControlId.turnSignalLeft,
        ControlId.turnSignalRight,
        ControlId.headlightToggle,
        ControlId.highBeamToggle,
        ControlId.cruiseToggle,
        ControlId.hazardLights,
        ControlId.beaconLights,
        ControlId.trailer,
        ControlId.liftDropAxle,
        ControlId.engineBrake,
        ControlId.differentialLock,
      ];
      for (final control in toggles) {
        expect(DashboardControl.modeFor(control), ControlMode.toggle,
            reason: control.name);
      }
    });

    test('engine start keeps hold-confirm', () {
      expect(DashboardControl.modeFor(ControlId.engineStart),
          ControlMode.holdConfirm);
    });

    test('everything else is momentary', () {
      const nonMomentary = [
        ControlId.turnSignalLeft,
        ControlId.turnSignalRight,
        ControlId.headlightToggle,
        ControlId.highBeamToggle,
        ControlId.cruiseToggle,
        ControlId.hazardLights,
        ControlId.beaconLights,
        ControlId.trailer,
        ControlId.liftDropAxle,
        ControlId.engineBrake,
        ControlId.differentialLock,
        ControlId.engineStart,
      ];
      for (final control in ControlId.values) {
        if (nonMomentary.contains(control)) continue;
        expect(DashboardControl.modeFor(control), ControlMode.momentary,
            reason: control.name);
      }
    });
  });

  group('ETS2 keyboard preset', () {
    test('new controls carry TODO defaults', () {
      const expected = {
        ControlId.hazardLights: 'F',
        ControlId.lightsOff: 'L',
        ControlId.lightsParking: 'L',
        ControlId.lightsLowbeam: 'L',
        ControlId.beaconLights: 'O',
        ControlId.flasher: 'J',
        ControlId.horn: 'H',
        ControlId.trailer: 'T',
        ControlId.liftDropAxle: 'U',
        ControlId.cameraView: '9',
        ControlId.gearUp: 'Left Shift',
        ControlId.gearDown: 'Left Ctrl',
        ControlId.engineBrake: 'B',
        ControlId.airHorn: 'N',
        ControlId.differentialLock: 'V',
        ControlId.retarderIncrease: ';',
        ControlId.retarderDecrease: "'",
        ControlId.quickInfo: 'F1',
        ControlId.mirrorToggle: 'F2',
        ControlId.hudWidgets: 'F3',
        ControlId.vehicleAdjustment: 'F4',
        ControlId.navigationZoomOut: 'F5',
        ControlId.widgetOptions: 'F6',
        ControlId.services: 'F7',
        ControlId.quickSave: 'Scroll Lock',
        ControlId.quickLoad: 'Pause',
        ControlId.screenshot: 'F10',
        ControlId.garageManager: 'G',
        ControlId.audioPlayer: 'R',
      };
      for (final entry in expected.entries) {
        expect(GamePreset.ets2.bindingFor(entry.key, false), entry.value,
            reason: entry.key.name);
      }
    });

    test('user-set-able controls default to empty in both modes', () {
      const empty = [
        ControlId.shiftToDrive,
        ControlId.shiftToReverse,
        ControlId.shiftToNeutral,
        ControlId.engineElectricity,
        ControlId.adaptiveCruise,
        ControlId.cruiseSpeedIncrease,
        ControlId.cruiseSpeedDecrease,
        ControlId.laneAssistant,
        ControlId.laneKeeping,
        ControlId.emergencyBrake,
        ControlId.wipersBack,
        // The audio row controls carry their REQ-026 keys now; only
        // audioFavorite remains unbound.
        ControlId.audioFavorite,
      ];
      for (final control in empty) {
        expect(GamePreset.ets2.bindingFor(control, false), '-',
            reason: '${control.name} keyboard');
        expect(GamePreset.ets2.bindingFor(control, true), '-',
            reason: '${control.name} gamepad');
      }
    });

    test('cruise and high-beam keep their verified bindings', () {
      // REQ-006: C/K verified against current values; no-op confirmed.
      expect(GamePreset.ets2.bindingFor(ControlId.cruiseToggle, false), 'C');
      expect(
          GamePreset.ets2.bindingFor(ControlId.highBeamToggle, false), 'K');
    });

    test('generic preset mirrors ETS2', () {
      for (final control in ControlId.values) {
        expect(GamePreset.generic.bindingFor(control, false),
            GamePreset.ets2.bindingFor(control, false),
            reason: '${control.name} keyboard');
        expect(GamePreset.generic.bindingFor(control, true),
            GamePreset.ets2.bindingFor(control, true),
            reason: '${control.name} gamepad');
      }
    });
  });
}
