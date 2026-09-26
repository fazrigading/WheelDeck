package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ControlId

/// Which extra dashboard controls appear in the grid. The core set (lights,
/// signals-free essentials) is always shown; these extras toggle in Settings.
///
/// Defaults: gears + engine brake ON, everything else OFF (REQ-009).
data class DashboardVisibility(val visibleExtras: Set<ControlId> = defaults) {

    fun isVisible(control: ControlId) = control in visibleExtras

    /// Copy with [control] flipped.
    fun toggled(control: ControlId) = DashboardVisibility(
        if (control in visibleExtras) visibleExtras - control else visibleExtras + control,
    )

    /// Wire values for persistence; unknown stored values are dropped.
    fun wireValues() = visibleExtras.mapTo(mutableSetOf()) { it.wireValue }

    companion object {
        /// Prefs key holding the visible extras as wire values.
        const val KEY = "wheeldeck.dashboard_extras"

        /// Extras with a Settings toggle. Never overlaps [coreControls].
        val toggleable = listOf(
            ControlId.GearUp,
            ControlId.GearDown,
            ControlId.EngineBrake,
            ControlId.AirHorn,
            ControlId.DifferentialLock,
            ControlId.RetarderIncrease,
            ControlId.RetarderDecrease,
            ControlId.QuickInfo,
            ControlId.MirrorToggle,
            ControlId.HudWidgets,
            ControlId.VehicleAdjustment,
            ControlId.NavigationZoomOut,
            ControlId.WidgetOptions,
            ControlId.Services,
            ControlId.QuickSave,
            ControlId.QuickLoad,
            ControlId.Screenshot,
            ControlId.GarageManager,
            ControlId.AudioPlayer,
            // Comfort and chat batch (TASK-049): all ten are plain momentary
            // buttons that make sense in a gyro grid, so they are toggleable.
            // Block E batch (TASK-049): dashboard_info and activate are plain
            // actions that make sense in a grid; the camera views, next_camera,
            // menu, world_map, and photo_mode stay out (REQ-011).
            ControlId.DriverWindowUp,
            ControlId.DriverWindowDown,
            ControlId.PassengerWindowUp,
            ControlId.PassengerWindowDown,
            ControlId.NavigationZoomIn,
            ControlId.OverlayActivation,
            ControlId.ChatActivation,
            ControlId.QuickReplies,
            ControlId.NameTags,
            ControlId.PushToTalk,
            ControlId.DashboardInfo,
            ControlId.Activate,
        )

        /// Gears and engine brake on, everything else off (REQ-009).
        val defaults = setOf(ControlId.GearUp, ControlId.GearDown, ControlId.EngineBrake)

        /// Always-shown grid controls. Turn signals never appear here: the
        /// rotatable grid's block A and the gyro signal row own them.
        /// Always-shown grid controls; turn signals are excluded by design.
        val coreControls = listOf(
            ControlId.HeadlightToggle,
            ControlId.HighBeamToggle,
            ControlId.CruiseToggle,
            ControlId.CruiseSetResume,
            ControlId.ParkingBrake,
            ControlId.Wipers,
            ControlId.EngineStart,
            ControlId.HazardLights,
            ControlId.BeaconLights,
            ControlId.Flasher,
            ControlId.Horn,
            ControlId.Trailer,
            ControlId.LiftDropAxle,
            ControlId.CameraView,
        )

        fun fromWireValues(stored: Set<String>?): DashboardVisibility =
            if (stored == null) {
                DashboardVisibility()
            } else {
                DashboardVisibility(
                    stored.mapNotNullTo(mutableSetOf()) { wire ->
                        ControlId.entries.firstOrNull { it.wireValue == wire }
                    },
                )
            }
    }
}
