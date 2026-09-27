package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.domain.models.ControlId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// The unbound-cell affordance: a cell the game preset does not bind renders
/// dead, and tapping it is the driver's cue to bind it (REQ-013). The dialog
/// itself is Compose, so what is checked here is which controls reach it and
/// which do not.
class UnboundCellBinderTest {

    private val bound = { control: ControlId -> GamePreset.Ets2.bindingFor(control, isGamepad = true) }

    @Test
    fun `a bound control is not offered to the binder`() {
        val offered = bound(ControlId.HazardLights)

        assertFalse(DashboardSendGate.isUnbound(offered))
    }

    @Test
    fun `the controls with no preset default are the ones that reach the binder`() {
        val unbound = ControlId.entries.filter { DashboardSendGate.isUnbound(bound(it)) }

        // The set the settings page has to make reachable, and the reason
        // tasks/task-12-leftovers.md calls this the one leftover that left the
        // app worse to use.
        for (control in listOf(
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
            ControlId.AudioFavorite,
        )) {
            assertTrue(control.wireValue, control in unbound)
        }
    }

    @Test
    fun `the camera pad is bound by the auto alias, so it never needs the binder`() {
        for (control in ControlId.entries.filter { it.wireValue.startsWith("camera_pad_") }) {
            assertEquals(control.wireValue, GamePreset.AUTO, bound(control))
        }
    }

    @Test
    fun `an arrow-mode diagonal is inert rather than unbound, so it offers nothing`() {
        // No control at all, so there is nothing to bind.
        assertEquals(null, cameraPadControlAt(0, 0, CameraPadMode.Arrow))
        // The center is a live hold surface in both modes.
        assertEquals(ControlId.CameraPadRecenter, cameraPadControlAt(1, 1, CameraPadMode.Numpad))
        assertEquals(null, cameraPadControlAt(1, 1, CameraPadMode.Arrow))
    }
}
