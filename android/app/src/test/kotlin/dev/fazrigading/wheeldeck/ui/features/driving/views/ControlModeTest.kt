package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.ui.core.ControlMode
import dev.fazrigading.wheeldeck.ui.core.ControlPress
import org.junit.Assert.assertEquals
import org.junit.Test

/// Port of the mode table and preset assertions in
/// mobile/test/ui/features/driving/control_mode_test.dart.
class ControlModeTest {

    private val toggles = listOf(
        ControlId.TurnSignalLeft,
        ControlId.TurnSignalRight,
        ControlId.HeadlightToggle,
        ControlId.HighBeamToggle,
        ControlId.CruiseToggle,
        ControlId.HazardLights,
        ControlId.BeaconLights,
        ControlId.Trailer,
        ControlId.LiftDropAxle,
        ControlId.EngineBrake,
        ControlId.DifferentialLock,
    )

    @Test
    fun `toggle-pulse controls`() {
        for (control in toggles) {
            assertEquals(control.wireValue, ControlMode.Toggle, ControlPress.modeFor(control))
        }
    }

    @Test
    fun `engine start keeps hold-confirm`() {
        assertEquals(ControlMode.HoldConfirm, ControlPress.modeFor(ControlId.EngineStart))
    }

    @Test
    fun `everything else is momentary`() {
        val nonMomentary = toggles + ControlId.EngineStart
        for (control in ControlId.entries) {
            if (control in nonMomentary) continue
            assertEquals(control.wireValue, ControlMode.Momentary, ControlPress.modeFor(control))
        }
    }

    @Test
    fun `the grid's engine start follows the setting`() {
        assertEquals(ControlMode.HoldConfirm, modeFor(ControlId.EngineStart, EngineStartMode.HoldConfirm))
        assertEquals(ControlMode.Momentary, modeFor(ControlId.EngineStart, EngineStartMode.SinglePress))
    }

    @Test
    fun `new controls carry TODO defaults`() {
        val expected = mapOf(
            ControlId.HazardLights to "F",
            ControlId.LightsOff to "L",
            ControlId.LightsParking to "L",
            ControlId.LightsLowbeam to "L",
            ControlId.BeaconLights to "O",
            ControlId.Flasher to "J",
            ControlId.Horn to "H",
            ControlId.Trailer to "T",
            ControlId.LiftDropAxle to "U",
            ControlId.CameraView to "9",
            ControlId.GearUp to "Left Shift",
            ControlId.GearDown to "Left Ctrl",
            ControlId.EngineBrake to "B",
            ControlId.AirHorn to "N",
            ControlId.DifferentialLock to "V",
            ControlId.RetarderIncrease to ";",
            ControlId.RetarderDecrease to "'",
            ControlId.QuickInfo to "F1",
            ControlId.MirrorToggle to "F2",
            ControlId.HudWidgets to "F3",
            ControlId.VehicleAdjustment to "F4",
            ControlId.NavigationZoomOut to "F5",
            ControlId.WidgetOptions to "F6",
            ControlId.Services to "F7",
            ControlId.QuickSave to "Scroll Lock",
            ControlId.QuickLoad to "Pause",
            ControlId.Screenshot to "F10",
            ControlId.GarageManager to "G",
            ControlId.AudioPlayer to "R",
        )
        for ((control, value) in expected) {
            assertEquals(control.wireValue, value, GamePreset.Ets2.bindingFor(control, isGamepad = false))
        }
    }

    @Test
    fun `user-set-able controls default to empty in both modes`() {
        val empty = listOf(
            ControlId.ShiftToDrive,
            ControlId.ShiftToReverse,
            ControlId.ShiftToNeutral,
            ControlId.EngineElectricity,
            ControlId.AdaptiveCruise,
            ControlId.CruiseSpeedIncrease,
            ControlId.CruiseSpeedDecrease,
            ControlId.LaneAssistant,
            ControlId.LaneKeeping,
            ControlId.EmergencyBrake,
            ControlId.WipersBack,
            // The audio row controls carry their REQ-026 keys now; only
            // audioFavorite remains unbound.
            ControlId.AudioFavorite,
        )
        for (control in empty) {
            assertEquals("${control.wireValue} keyboard", "-", GamePreset.Ets2.bindingFor(control, isGamepad = false))
            assertEquals("${control.wireValue} gamepad", "-", GamePreset.Ets2.bindingFor(control, isGamepad = true))
        }
    }

    @Test
    fun `cruise and high-beam keep their verified bindings`() {
        // REQ-006: C/K verified against current values; no-op confirmed.
        assertEquals("C", GamePreset.Ets2.bindingFor(ControlId.CruiseToggle, isGamepad = false))
        assertEquals("K", GamePreset.Ets2.bindingFor(ControlId.HighBeamToggle, isGamepad = false))
    }

    @Test
    fun `generic preset mirrors ETS2`() {
        for (control in ControlId.entries) {
            assertEquals(
                "${control.wireValue} keyboard",
                GamePreset.Ets2.bindingFor(control, isGamepad = false),
                GamePreset.Generic.bindingFor(control, isGamepad = false),
            )
            assertEquals(
                "${control.wireValue} gamepad",
                GamePreset.Ets2.bindingFor(control, isGamepad = true),
                GamePreset.Generic.bindingFor(control, isGamepad = true),
            )
        }
    }
}
