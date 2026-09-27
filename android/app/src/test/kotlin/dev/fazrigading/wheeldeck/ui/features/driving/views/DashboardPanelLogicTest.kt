package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.DashboardGateState
import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.LightStage
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.ui.core.ControlMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of the presentation cases in
/// mobile/test/ui/features/driving/dashboard_panel_test.dart. The tap, hold, and
/// gate events it drives are covered by ControlPressTest and
/// DashboardSendGateTest; what is checked here is which cells the panel shows and
/// how a cell reads.
class DashboardPanelLogicTest {

    @Test
    fun `a control is never both core and a toggleable extra`() {
        val core = DashboardVisibility.coreControls.toSet()

        assertTrue(DashboardVisibility.toggleable.none { it in core })
    }

    @Test
    fun `an unbound control is disabled`() {
        val dash = { _: ControlId -> "-" }
        val bound = { _: ControlId -> "K" }

        assertTrue(DashboardSendGate.isUnbound(dash(ControlId.Horn)))
        assertTrue(DashboardSendGate.isUnbound(""))
        assertFalse(DashboardSendGate.isUnbound(bound(ControlId.Horn)))
    }

    @Test
    fun `engine start follows the setting`() {
        assertEquals(
            ControlMode.HoldConfirm,
            modeFor(ControlId.EngineStart, EngineStartMode.HoldConfirm),
        )
        assertEquals(
            ControlMode.Momentary,
            modeFor(ControlId.EngineStart, EngineStartMode.SinglePress),
        )
    }

    @Test
    fun `cells print their short label, not their wire value`() {
        val expected = mapOf(
            ControlId.HighBeamToggle to "BEAM",
            ControlId.CruiseToggle to "CRUISE",
            ControlId.CruiseSetResume to "RESUME",
            ControlId.ParkingBrake to "PARK",
            ControlId.Wipers to "WIPE",
            ControlId.EngineStart to "START",
            ControlId.HazardLights to "HAZARD",
            ControlId.BeaconLights to "BEACON",
            ControlId.Flasher to "FLASH",
            ControlId.Horn to "HORN",
            ControlId.Trailer to "TRAILER",
            ControlId.LiftDropAxle to "AXLE",
            ControlId.CameraView to "CAM",
            ControlId.GearUp to "GEAR+",
            ControlId.GearDown to "GEAR-",
            ControlId.EngineBrake to "E-BRK",
            ControlId.AirHorn to "AIR",
            ControlId.DifferentialLock to "DIFF",
            ControlId.RetarderIncrease to "RET+",
            ControlId.RetarderDecrease to "RET-",
            ControlId.QuickInfo to "INFO",
            ControlId.MirrorToggle to "MIRROR",
            ControlId.HudWidgets to "HUD",
            ControlId.VehicleAdjustment to "VEH",
            ControlId.NavigationZoomOut to "NAV",
            ControlId.WidgetOptions to "WIDGET",
            ControlId.Services to "SVC",
            ControlId.QuickSave to "SAVE",
            ControlId.QuickLoad to "LOAD",
            ControlId.Screenshot to "SHOT",
            ControlId.GarageManager to "GARAGE",
            ControlId.AudioPlayer to "AUDIO",
        )
        for ((control, label) in expected) {
            assertEquals(control.wireValue, label, cellLabel(control, DashboardGateState()))
        }
    }

    @Test
    fun `a control with no short label falls back to its wire value`() {
        assertEquals("lane_assistant", cellLabel(ControlId.LaneAssistant, DashboardGateState()))
        assertEquals("camera_pad_up", cellLabel(ControlId.CameraPadUp, DashboardGateState()))
    }

    @Test
    fun `the headlight cell's label is the cycle stage, not LIGHT`() {
        assertEquals("OFF", cellLabel(ControlId.HeadlightToggle, DashboardGateState()))
        assertEquals(
            "PARK",
            cellLabel(ControlId.HeadlightToggle, DashboardGateState(lightStage = LightStage.Parking)),
        )
        assertEquals(
            "LOW",
            cellLabel(ControlId.HeadlightToggle, DashboardGateState(lightStage = LightStage.Low)),
        )
    }
}
