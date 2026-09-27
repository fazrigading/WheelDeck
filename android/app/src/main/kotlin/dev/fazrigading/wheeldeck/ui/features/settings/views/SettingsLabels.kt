package dev.fazrigading.wheeldeck.ui.features.settings.views

import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType

/// Human labels for the settings and keybind pages, ported verbatim from
/// `settings_screen.dart`'s `_controlLabel`. The dashboard cells use their own
/// short labels; these are the full names a driver reads in a list, so they are
/// exhaustive — a control with no entry here would render a raw enum name.
private val CONTROL_LABELS: Map<ControlId, String> = mapOf(
    ControlId.ParkingBrake to "Parking brake",
    ControlId.TurnSignalLeft to "Turn signal L",
    ControlId.TurnSignalRight to "Turn signal R",
    ControlId.HeadlightToggle to "Headlights",
    ControlId.LightsOff to "Lights off",
    ControlId.LightsParking to "Lights parking",
    ControlId.LightsLowbeam to "Lights low beam",
    ControlId.HighBeamToggle to "High-beam",
    ControlId.Wipers to "Wipers",
    ControlId.CruiseToggle to "Cruise toggle",
    ControlId.CruiseSetResume to "Cruise resume",
    ControlId.EngineStart to "Engine start",
    ControlId.HazardLights to "Hazard lights",
    ControlId.BeaconLights to "Beacon lights",
    ControlId.Flasher to "Flasher",
    ControlId.Horn to "Horn",
    ControlId.Trailer to "Trailer",
    ControlId.LiftDropAxle to "Lift/drop axle",
    ControlId.CameraView to "Camera view",
    ControlId.GearUp to "Gear up",
    ControlId.GearDown to "Gear down",
    ControlId.EngineBrake to "Engine brake",
    ControlId.AirHorn to "Air horn",
    ControlId.DifferentialLock to "Differential lock",
    ControlId.RetarderIncrease to "Retarder +",
    ControlId.RetarderDecrease to "Retarder -",
    ControlId.QuickInfo to "Quick info",
    ControlId.MirrorToggle to "Mirror",
    ControlId.HudWidgets to "HUD widgets",
    ControlId.VehicleAdjustment to "Vehicle adjustment",
    ControlId.NavigationZoomOut to "Nav zoom out",
    ControlId.WidgetOptions to "Widget options",
    ControlId.Services to "Services",
    ControlId.QuickSave to "Quick save",
    ControlId.QuickLoad to "Quick load",
    ControlId.Screenshot to "Screenshot",
    ControlId.GarageManager to "Garage",
    ControlId.AudioPlayer to "Audio player",
    ControlId.ShiftToDrive to "Shift to drive",
    ControlId.ShiftToReverse to "Shift to reverse",
    ControlId.ShiftToNeutral to "Shift to neutral",
    ControlId.EngineElectricity to "Engine electricity",
    ControlId.AdaptiveCruise to "Adaptive cruise",
    ControlId.CruiseSpeedIncrease to "Cruise speed +",
    ControlId.CruiseSpeedDecrease to "Cruise speed -",
    ControlId.LaneAssistant to "Lane assistant",
    ControlId.LaneKeeping to "Lane keeping",
    ControlId.EmergencyBrake to "Emergency brake",
    ControlId.WipersBack to "Wipers back",
    ControlId.AudioPlayPause to "Audio play/pause",
    ControlId.AudioNext to "Audio next",
    ControlId.AudioPrevious to "Audio previous",
    ControlId.AudioVolumeUp to "Audio vol +",
    ControlId.AudioVolumeDown to "Audio vol -",
    ControlId.AudioFavorite to "Audio favorite",
    ControlId.TrailerAxle to "Trailer axle",
    ControlId.DriverWindowUp to "Driver window up",
    ControlId.DriverWindowDown to "Driver window down",
    ControlId.PassengerWindowUp to "Passenger window up",
    ControlId.PassengerWindowDown to "Passenger window down",
    ControlId.NavigationZoomIn to "Nav zoom in",
    ControlId.OverlayActivation to "Overlay",
    ControlId.ChatActivation to "Chat",
    ControlId.QuickReplies to "Quick replies",
    ControlId.NameTags to "Name tags",
    ControlId.PushToTalk to "Push to talk",
    ControlId.CameraInterior to "Camera interior",
    ControlId.CameraChasing to "Camera chasing",
    ControlId.CameraTopdown to "Camera top-down",
    ControlId.CameraRoof to "Camera roof",
    ControlId.CameraLeanout to "Camera lean-out",
    ControlId.DashboardInfo to "Dashboard info",
    ControlId.NextCamera to "Next camera",
    ControlId.Menu to "Menu",
    ControlId.WorldMap to "World map",
    ControlId.PhotoMode to "Photo mode",
    ControlId.Activate to "Activate",
    ControlId.CameraPadUp to "Camera up",
    ControlId.CameraPadDown to "Camera down",
    ControlId.CameraPadLeft to "Camera left",
    ControlId.CameraPadRight to "Camera right",
    ControlId.CameraPadUpLeft to "Camera up-left",
    ControlId.CameraPadUpRight to "Camera up-right",
    ControlId.CameraPadDownLeft to "Camera down-left",
    ControlId.CameraPadDownRight to "Camera down-right",
    ControlId.CameraPadRecenter to "Recenter camera",
    ControlId.CameraPadArrowUp to "Camera arrow up",
    ControlId.CameraPadArrowDown to "Camera arrow down",
    ControlId.CameraPadArrowLeft to "Camera arrow left",
    ControlId.CameraPadArrowRight to "Camera arrow right",
    ControlId.CameraSimpleLeft to "Look left window",
    ControlId.CameraSimpleRight to "Look right window",
)

/// The label for [control]. Every control has one, so this never falls through.
fun controlLabel(control: ControlId): String =
    CONTROL_LABELS.getValue(control)

/// The label for [pedal].
fun pedalLabel(pedal: PedalType): String = when (pedal) {
    PedalType.Accelerator -> "Accelerator"
    PedalType.Brake -> "Brake"
    PedalType.Clutch -> "Clutch"
}
