enum ControlId {
  parkingBrake('parking_brake'),
  turnSignalLeft('turn_signal_left'),
  turnSignalRight('turn_signal_right'),
  headlightToggle('headlight_toggle'),
  highBeamToggle('high_beam_toggle'),
  wipers('wipers'),
  cruiseToggle('cruise_toggle'),
  cruiseSetResume('cruise_set_resume'),
  engineStart('engine_start');

  const ControlId(this.wireValue);

  /// Snake_case value used on the wire, matching protocol/schema/controls.json.
  final String wireValue;
}

enum ActionType {
  toggle('toggle'),
  press('press'),
  release('release'),
  holdConfirm('hold_confirm');

  const ActionType(this.wireValue);

  /// Snake_case value used on the wire, matching protocol/schema/controls.json.
  final String wireValue;
}

/// Receives discrete dashboard control events from the UI.
class DashboardInput {
  void Function(ControlId control, ActionType action)? _onControlActivated;

  /// Registers the callback that receives dashboard control events.
  void onControlActivated(
    void Function(ControlId control, ActionType action) callback,
  ) {
    _onControlActivated = callback;
  }

  /// Reports a dashboard control event.
  void activate(ControlId control, ActionType action) {
    _onControlActivated?.call(control, action);
  }
}
