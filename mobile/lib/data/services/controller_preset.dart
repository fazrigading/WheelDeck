import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_input.dart';

/// Game-specific button presets. Wire values mirror desktop InputMapper defaults (ETS2).
enum GamePreset {
  ets2('ets2', 'Euro Truck Simulator 2'),
  generic('generic', 'Generic');

  const GamePreset(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static const String prefsKey = 'wheeldeck.game_preset';
  static const GamePreset fallback = ets2;

  static GamePreset fromWireValue(String? v) => GamePreset.values
      .firstWhere((p) => p.wireValue == v, orElse: () => fallback);

  /// Loads the persisted preset, defaulting to ETS2. Needed so driving can
  /// resolve per-preset settings (e.g. rotation degrees).
  static Future<GamePreset> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }

  /// Default bindings for keyboard / gamepad, mirroring WheelDeck.Core InputMapper.
  static const Map<ControlId, String> ets2Keyboard = {
    ControlId.parkingBrake: 'Space',
    ControlId.turnSignalLeft: '[',
    ControlId.turnSignalRight: ']',
    ControlId.headlightToggle: 'L',
    ControlId.highBeamToggle: 'K',
    ControlId.wipers: 'P',
    ControlId.cruiseToggle: 'C',
    ControlId.cruiseSetResume: 'R',
    ControlId.engineStart: 'E',
    ControlId.hazardLights: 'F',
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

  /// Gamepad labels for the driving-relevant extras. Menu-type extras and the
  /// user-set-able set have no gamepad default ('-'), so the phone gates
  /// them instead of sending.
  static const Map<ControlId, String> ets2Gamepad = {
    ControlId.parkingBrake: 'A',
    ControlId.turnSignalLeft: 'DPadLeft',
    ControlId.turnSignalRight: 'DPadRight',
    ControlId.headlightToggle: 'B',
    ControlId.highBeamToggle: 'Y',
    ControlId.wipers: 'X',
    ControlId.cruiseToggle: 'LB',
    ControlId.cruiseSetResume: 'RB',
    ControlId.engineStart: 'Start',
    ControlId.hazardLights: 'Back',
    ControlId.horn: 'LeftThumb',
    ControlId.cameraView: 'RightThumb',
    ControlId.gearUp: 'DPadUp',
    ControlId.gearDown: 'DPadDown',
  };

  String bindingFor(ControlId id, bool isGamepad) {
    final map = isGamepad ? ets2Gamepad : ets2Keyboard;
    return map[id] ?? '-';
  }
}
