package dev.fazrigading.wheeldeck.ui.features.driving.views

import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.PedalInput
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// Ports the mapping cases of
/// mobile/test/ui/features/driving/{wheel_view,tilt_readout,pedal_panel,camera_pad}_test.dart
/// that do not need a rendered widget.
@OptIn(ExperimentalCoroutinesApi::class)
class DrivingWidgetLogicTest {

    @Test
    fun `maps a normalized angle to wheel rotation in turns`() {
        assertEquals(0.25, wheelTurns(1.0), 1e-9)
        assertEquals(-0.25, wheelTurns(-1.0), 1e-9)
    }

    @Test
    fun `zero angle keeps the wheel centered`() {
        assertEquals(0.0, wheelTurns(0.0), 1e-9)
    }

    @Test
    fun `clamps out-of-range angles to full lock`() {
        assertEquals(-0.25, wheelTurns(-2.5), 1e-9)
        assertEquals(0.25, wheelTurns(7.0), 1e-9)
    }

    @Test
    fun `the tilt marker mirrors the steering angle`() {
        assertEquals(0f, tiltMarkerFraction(-1.0), 1e-6f)
        assertEquals(0.5f, tiltMarkerFraction(0.0), 1e-6f)
        assertEquals(1f, tiltMarkerFraction(1.0), 1e-6f)
        assertEquals(0.25f, tiltMarkerFraction(-0.5), 1e-6f)
        assertEquals(1f, tiltMarkerFraction(4.0), 1e-6f)
    }

    @Test
    fun `drags down to increase pressure and up toward rest`() {
        assertEquals(1.0, pedalPressureFromOffset(300f, 300f), 1e-9)
        assertEquals(0.0, pedalPressureFromOffset(0f, 300f), 1e-9)
        assertEquals(0.5, pedalPressureFromOffset(150f, 300f), 1e-9)
    }

    @Test
    fun `pedal pressure clamps outside the bar`() {
        assertEquals(1.0, pedalPressureFromOffset(500f, 300f), 1e-9)
        assertEquals(0.0, pedalPressureFromOffset(-40f, 300f), 1e-9)
        assertEquals(0.0, pedalPressureFromOffset(10f, 0f), 1e-9)
    }

    @Test
    fun `every pedal has its own hue`() {
        val hues = PedalType.entries.map(::pedalColor)
        assertEquals("every pedal needs its own hue", hues.size, hues.toSet().size)
    }

    @Test
    fun `numpad mode sends the numpad-set controls`() {
        assertEquals(ControlId.CameraPadUp, cameraPadControlAt(0, 1, CameraPadMode.Numpad))
        assertEquals(ControlId.CameraPadUpLeft, cameraPadControlAt(0, 0, CameraPadMode.Numpad))
        assertEquals(ControlId.CameraPadDownRight, cameraPadControlAt(2, 2, CameraPadMode.Numpad))
        assertEquals(ControlId.CameraPadRecenter, cameraPadControlAt(1, 1, CameraPadMode.Numpad))
    }

    @Test
    fun `arrow mode sends the arrow-set controls`() {
        assertEquals(ControlId.CameraPadArrowUp, cameraPadControlAt(0, 1, CameraPadMode.Arrow))
        assertEquals(ControlId.CameraPadArrowLeft, cameraPadControlAt(1, 0, CameraPadMode.Arrow))
        assertEquals(ControlId.CameraPadArrowRight, cameraPadControlAt(1, 2, CameraPadMode.Arrow))
        assertEquals(ControlId.CameraPadArrowDown, cameraPadControlAt(2, 1, CameraPadMode.Arrow))
    }

    @Test
    fun `arrow mode disables the four diagonals and the center press`() {
        val diagonals = listOf(0 to 0, 0 to 2, 2 to 0, 2 to 2)
        diagonals.forEach { (row, col) ->
            assertNull(cameraPadControlAt(row, col, CameraPadMode.Arrow))
            assertEquals(CameraPadCellKind.Inert, cameraPadCellKind(row, col, CameraPadMode.Arrow))
        }
        // Recenter is a numpad-set key: the center still holds, but sends nothing.
        assertNull(cameraPadControlAt(1, 1, CameraPadMode.Arrow))
        assertEquals(CameraPadCellKind.Center, cameraPadCellKind(1, 1, CameraPadMode.Arrow))
    }

    @Test
    fun `the center cell is live in both modes`() {
        val bound = { _: ControlId -> "K" }
        listOf(CameraPadMode.Numpad, CameraPadMode.Arrow).forEach { mode ->
            val kind = cameraPadCellKind(1, 1, mode)
            assertTrue(
                "the center must stay live in $mode",
                cameraPadCellEnabled(cameraPadControlAt(1, 1, mode), kind, bound),
            )
        }
    }

    @Test
    fun `an unbound direction cell is disabled and an inert cell never is`() {
        val unbound = { _: ControlId -> "" }
        val dash = { _: ControlId -> "-" }
        val bound = { _: ControlId -> "K" }
        val direction = CameraPadCellKind.Direction

        assertFalse(cameraPadCellEnabled(ControlId.CameraPadUp, direction, unbound))
        assertFalse(cameraPadCellEnabled(ControlId.CameraPadUp, direction, dash))
        assertTrue(cameraPadCellEnabled(ControlId.CameraPadUp, direction, bound))
        assertFalse(cameraPadCellEnabled(null, CameraPadCellKind.Inert, bound))
    }

    @Test
    fun `the center cell labels the active key set`() {
        assertEquals("NUM", cameraPadLabel(1, 1, CameraPadMode.Numpad))
        assertEquals("ARR", cameraPadLabel(1, 1, CameraPadMode.Arrow))
        assertEquals("↑", cameraPadLabel(0, 1, CameraPadMode.Arrow))
        assertEquals("", cameraPadLabel(0, 0, CameraPadMode.Arrow))
    }

    @Test
    fun `a pedal bar drag drives PedalInput and releases back`() = runTest {
        val input = PedalInput(scope = backgroundScope, releaseDurationMs = 0)

        // Exactly what the bar's pointer handling forwards on a drag.
        val dragged = dragPedalTo(PedalType.Accelerator, 240f, 300f, input::setPressure)
        // Float pixels, so a loose tolerance.
        assertEquals(0.8, dragged, 1e-6)
        assertEquals(0.8, input.pressureOf(PedalType.Accelerator), 1e-6)

        input.release(PedalType.Accelerator)
        assertEquals(0.0, input.pressureOf(PedalType.Accelerator), 1e-9)
    }

    @Test
    fun `the default pedal order is clutch, brake, accelerator`() {
        assertEquals(
            listOf(PedalType.Clutch, PedalType.Brake, PedalType.Accelerator),
            defaultPedalOrder,
        )
    }
}
