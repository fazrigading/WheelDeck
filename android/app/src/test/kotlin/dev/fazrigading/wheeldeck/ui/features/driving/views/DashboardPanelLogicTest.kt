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
    fun `the headlight cell shows the gate's cycle stage`() {
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

    @Test
    fun `other cells label themselves with their wire value`() {
        assertEquals("wipers", cellLabel(ControlId.Wipers, DashboardGateState()))
        assertEquals("hazard_lights", cellLabel(ControlId.HazardLights, DashboardGateState()))
    }
}
