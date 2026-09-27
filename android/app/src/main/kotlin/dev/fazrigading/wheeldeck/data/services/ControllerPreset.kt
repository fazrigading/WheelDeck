package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ControlId

/// Game-specific button presets. Wire values mirror desktop InputMapper defaults
/// (ETS2).
enum class GamePreset(val wireValue: String, val label: String) {
    Ets2("ets2", "Euro Truck Simulator 2"),
    Generic("generic", "Generic");

    companion object {
        const val KEY = "wheeldeck.game_preset"
        val fallback = Ets2

        fun fromWireValue(value: String?): GamePreset =
            entries.firstOrNull { it.wireValue == value } ?: fallback

        /// Sentinel binding for keys the desktop's InputMapper already owns
        /// (numpad block, arrow keys): the phone sends the control and never
        /// asks the driver for a keybind — TODO.md Dashboard 4.
        const val AUTO = "auto"

        /// The unbound marker the presets and the send gate agree on.
        const val UNBOUND = "-"

        /// Every camera-pad control's wire prefix. The desktop binds all of them
        /// (numpad block and arrow keys) but none has a user-facing label, so the
        /// phone aliases them instead of asking.
        const val CAMERA_PAD_PREFIX = "camera_pad_"

        /// Default keyboard bindings, mirroring WheelDeck.Core InputMapper.
        val ets2Keyboard: Map<ControlId, String> = buildMap {
            put(ControlId.ParkingBrake, "Space")
            put(ControlId.TurnSignalLeft, "[")
            put(ControlId.TurnSignalRight, "]")
            put(ControlId.HeadlightToggle, "L")
            put(ControlId.LightsOff, "L")
            put(ControlId.LightsParking, "L")
            put(ControlId.LightsLowbeam, "L")
            put(ControlId.HighBeamToggle, "K")
            put(ControlId.Wipers, "P")
            put(ControlId.CruiseToggle, "C")
            put(ControlId.CruiseSetResume, "R")
            put(ControlId.EngineStart, "E")
            put(ControlId.HazardLights, "F")
            put(ControlId.BeaconLights, "O")
            put(ControlId.Flasher, "J")
            put(ControlId.Horn, "H")
            put(ControlId.Trailer, "T")
            // Shares T with the trailer, mirroring the desktop InputMapper.
            put(ControlId.TrailerAxle, "T")
            // Audio row keys per REQ-026, replacing inert defaults.
            put(ControlId.AudioVolumeDown, "L")
            put(ControlId.AudioPrevious, "J")
            put(ControlId.AudioPlayPause, "K")
            put(ControlId.AudioNext, "U")
            put(ControlId.AudioVolumeUp, "O")
            // Comfort and chat batch, mirroring the desktop InputMapper.
            put(ControlId.DriverWindowUp, "Right Shift")
            put(ControlId.NavigationZoomIn, "/")
            put(ControlId.DriverWindowDown, "Right Ctrl")
            put(ControlId.PassengerWindowUp, ",")
            put(ControlId.PassengerWindowDown, ".")
            put(ControlId.OverlayActivation, "Tab")
            put(ControlId.ChatActivation, "Y")
            put(ControlId.QuickReplies, "Q")
            put(ControlId.NameTags, "Z")
            put(ControlId.PushToTalk, "X")
            // Cameras and menu batch, mirroring the desktop InputMapper.
            put(ControlId.CameraInterior, "1")
            put(ControlId.CameraChasing, "2")
            put(ControlId.CameraTopdown, "3")
            put(ControlId.CameraRoof, "4")
            put(ControlId.CameraLeanout, "5")
            put(ControlId.DashboardInfo, "I")
            // Shares 9 with the camera view, mirroring the desktop InputMapper.
            put(ControlId.NextCamera, "9")
            put(ControlId.Menu, "Escape")
            put(ControlId.WorldMap, "M")
            put(ControlId.PhotoMode, "=")
            put(ControlId.Activate, "Enter")
            put(ControlId.LiftDropAxle, "U")
            put(ControlId.CameraView, "9")
            put(ControlId.GearUp, "Left Shift")
            put(ControlId.GearDown, "Left Ctrl")
            put(ControlId.EngineBrake, "B")
            put(ControlId.AirHorn, "N")
            put(ControlId.DifferentialLock, "V")
            put(ControlId.RetarderIncrease, ";")
            put(ControlId.RetarderDecrease, "'")
            put(ControlId.QuickInfo, "F1")
            put(ControlId.MirrorToggle, "F2")
            put(ControlId.HudWidgets, "F3")
            put(ControlId.VehicleAdjustment, "F4")
            put(ControlId.NavigationZoomOut, "F5")
            put(ControlId.WidgetOptions, "F6")
            put(ControlId.Services, "F7")
            put(ControlId.QuickSave, "Scroll Lock")
            put(ControlId.QuickLoad, "Pause")
            put(ControlId.Screenshot, "F10")
            put(ControlId.GarageManager, "G")
            put(ControlId.AudioPlayer, "R")
        }

        /// Gamepad labels for the driving-relevant extras. Menu-type extras and
        /// the user-set-able set have no gamepad default, so the phone gates them
        /// instead of sending.
        val ets2Gamepad: Map<ControlId, String> = buildMap {
            put(ControlId.ParkingBrake, "A")
            put(ControlId.TurnSignalLeft, "DPadLeft")
            put(ControlId.TurnSignalRight, "DPadRight")
            put(ControlId.HeadlightToggle, "B")
            put(ControlId.LightsOff, "B")
            put(ControlId.LightsParking, "B")
            put(ControlId.LightsLowbeam, "B")
            put(ControlId.HighBeamToggle, "Y")
            put(ControlId.Wipers, "X")
            put(ControlId.CruiseToggle, "LB")
            put(ControlId.CruiseSetResume, "RB")
            put(ControlId.EngineStart, "Start")
            put(ControlId.HazardLights, "Back")
            put(ControlId.Horn, "LeftThumb")
            put(ControlId.CameraView, "RightThumb")
            put(ControlId.GearUp, "DPadUp")
            put(ControlId.GearDown, "DPadDown")
        }
    }

    /// Resolves the preset default for [id]. Gamepad mode is gamepad-first:
    /// controls the gamepad map lacks fall back to their keyboard default, so the
    /// phone agrees with the desktop's hybrid routing (REQ-023).
    ///
    /// A control in neither table is unbound ([UNBOUND], the gate sends nothing)
    /// unless the desktop's InputMapper already owns its key, which is the case
    /// for the whole camera pad — those resolve to [AUTO] in both mapping modes
    /// so the first press sends instead of prompting for a keybind
    /// (TODO.md Dashboard 4).
    fun bindingFor(id: ControlId, isGamepad: Boolean): String {
        val table = if (isGamepad) ets2Gamepad[id] ?: ets2Keyboard[id] else ets2Keyboard[id]
        return table ?: if (id.wireValue.startsWith(CAMERA_PAD_PREFIX)) AUTO else UNBOUND
    }
}
