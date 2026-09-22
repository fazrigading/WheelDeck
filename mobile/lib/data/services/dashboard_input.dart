enum ControlId {
  parkingBrake('parking_brake'),
  turnSignalLeft('turn_signal_left'),
  turnSignalRight('turn_signal_right'),
  headlightToggle('headlight_toggle'),
  lightsOff('lights_off'),
  lightsParking('lights_parking'),
  lightsLowbeam('lights_lowbeam'),
  highBeamToggle('high_beam_toggle'),
  wipers('wipers'),
  cruiseToggle('cruise_toggle'),
  cruiseSetResume('cruise_set_resume'),
  engineStart('engine_start'),
  hazardLights('hazard_lights'),
  beaconLights('beacon_lights'),
  flasher('flasher'),
  horn('horn'),
  trailer('trailer'),
  liftDropAxle('lift_drop_axle'),
  cameraView('camera_view'),
  gearUp('gear_up'),
  gearDown('gear_down'),
  engineBrake('engine_brake'),
  airHorn('air_horn'),
  differentialLock('differential_lock'),
  retarderIncrease('retarder_increase'),
  retarderDecrease('retarder_decrease'),
  quickInfo('quick_info'),
  mirrorToggle('mirror_toggle'),
  hudWidgets('hud_widgets'),
  vehicleAdjustment('vehicle_adjustment'),
  navigationZoomOut('navigation_zoom_out'),
  widgetOptions('widget_options'),
  services('services'),
  quickSave('quick_save'),
  quickLoad('quick_load'),
  screenshot('screenshot'),
  garageManager('garage_manager'),
  audioPlayer('audio_player'),
  shiftToDrive('shift_to_drive'),
  shiftToReverse('shift_to_reverse'),
  shiftToNeutral('shift_to_neutral'),
  engineElectricity('engine_electricity'),
  adaptiveCruise('adaptive_cruise'),
  cruiseSpeedIncrease('cruise_speed_increase'),
  cruiseSpeedDecrease('cruise_speed_decrease'),
  laneAssistant('lane_assistant'),
  laneKeeping('lane_keeping'),
  emergencyBrake('emergency_brake'),
  wipersBack('wipers_back'),
  audioPlayPause('audio_play_pause'),
  audioNext('audio_next'),
  audioPrevious('audio_previous'),
  audioVolumeUp('audio_volume_up'),
  audioVolumeDown('audio_volume_down'),
  audioFavorite('audio_favorite'),
  trailerAxle('trailer_axle'),
  driverWindowUp('driver_window_up'),
  driverWindowDown('driver_window_down'),
  passengerWindowUp('passenger_window_up'),
  passengerWindowDown('passenger_window_down'),
  navigationZoomIn('navigation_zoom_in'),
  overlayActivation('overlay_activation'),
  chatActivation('chat_activation'),
  quickReplies('quick_replies'),
  nameTags('name_tags'),
  pushToTalk('push_to_talk'),
  cameraInterior('camera_interior'),
  cameraChasing('camera_chasing'),
  cameraTopdown('camera_topdown'),
  cameraRoof('camera_roof'),
  cameraLeanout('camera_leanout'),
  dashboardInfo('dashboard_info'),
  nextCamera('next_camera'),
  menu('menu'),
  worldMap('world_map'),
  photoMode('photo_mode'),
  activate('activate'),
  // Camera pad, numpad mode (ADR-0006: the mode lives in the identifiers).
  cameraPadUp('camera_pad_up'),
  cameraPadDown('camera_pad_down'),
  cameraPadLeft('camera_pad_left'),
  cameraPadRight('camera_pad_right'),
  cameraPadUpLeft('camera_pad_up_left'),
  cameraPadUpRight('camera_pad_up_right'),
  cameraPadDownLeft('camera_pad_down_left'),
  cameraPadDownRight('camera_pad_down_right'),
  cameraPadRecenter('camera_pad_recenter'),
  // Camera pad, arrow mode; the four diagonals are disabled and have none.
  cameraPadArrowUp('camera_pad_arrow_up'),
  cameraPadArrowDown('camera_pad_arrow_down'),
  cameraPadArrowLeft('camera_pad_arrow_left'),
  cameraPadArrowRight('camera_pad_arrow_right'),
  // Simple camera type (REQ-013); recenter reuses cameraPadRecenter.
  cameraSimpleLeft('camera_simple_left'),
  cameraSimpleRight('camera_simple_right');

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
