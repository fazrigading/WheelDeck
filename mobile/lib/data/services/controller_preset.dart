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
  };

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
  };

  String bindingFor(ControlId id, bool isGamepad) {
    final map = isGamepad ? ets2Gamepad : ets2Keyboard;
    return map[id] ?? '-';
  }
}
