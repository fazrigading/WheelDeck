import 'dashboard_input.dart';

/// Game-specific button presets. Wire values mirror desktop InputMapper defaults (ETS2).
enum GamePreset {
  ets2('ets2', 'Euro Truck Simulator 2'),
  generic('generic', 'Generic');

  const GamePreset(this.wireValue, this.label);
  final String wireValue;
  final String label;

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
