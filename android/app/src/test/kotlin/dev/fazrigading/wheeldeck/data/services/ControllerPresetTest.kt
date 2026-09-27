package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of mobile/test/data/services/controller_preset_test.dart.
class ControllerPresetTest {

    private fun keyboard(id: ControlId) = GamePreset.Ets2.bindingFor(id, isGamepad = false)
    private fun gamepad(id: ControlId) = GamePreset.Ets2.bindingFor(id, isGamepad = true)

    @Test
    fun `keyboard mode reads the keyboard map`() {
        assertEquals("Space", keyboard(ControlId.ParkingBrake))
        assertEquals("Left Shift", keyboard(ControlId.GearUp))
    }

    @Test
    fun `comfort and chat batch reads the keyboard map`() {
        assertEquals("Right Shift", keyboard(ControlId.DriverWindowUp))
        assertEquals("/", keyboard(ControlId.NavigationZoomIn))
        assertEquals("Tab", keyboard(ControlId.OverlayActivation))
        assertEquals("X", keyboard(ControlId.PushToTalk))
    }

    @Test
    fun `cameras and menu batch reads the keyboard map`() {
        assertEquals("1", keyboard(ControlId.CameraInterior))
        assertEquals("5", keyboard(ControlId.CameraLeanout))
        assertEquals("I", keyboard(ControlId.DashboardInfo))
        assertEquals("9", keyboard(ControlId.NextCamera))
        assertEquals("Escape", keyboard(ControlId.Menu))
        assertEquals("M", keyboard(ControlId.WorldMap))
        assertEquals("=", keyboard(ControlId.PhotoMode))
        assertEquals("Enter", keyboard(ControlId.Activate))
    }

    @Test
    fun `audio row keys replace the inert defaults`() {
        assertEquals("L", keyboard(ControlId.AudioVolumeDown))
        assertEquals("J", keyboard(ControlId.AudioPrevious))
        assertEquals("K", keyboard(ControlId.AudioPlayPause))
        assertEquals("U", keyboard(ControlId.AudioNext))
        assertEquals("O", keyboard(ControlId.AudioVolumeUp))
    }

    @Test
    fun `batch controls fall back to keyboard in gamepad mode`() {
        assertEquals("Right Shift", gamepad(ControlId.DriverWindowUp))
        assertEquals("Y", gamepad(ControlId.ChatActivation))
    }

    @Test
    fun `gamepad mode reads the gamepad map`() {
        assertEquals("A", gamepad(ControlId.ParkingBrake))
        assertEquals("Back", gamepad(ControlId.HazardLights))
        assertEquals("DPadUp", gamepad(ControlId.GearUp))
    }

    @Test
    fun `gamepad mode falls back to the keyboard map for missing controls`() {
        assertEquals("O", gamepad(ControlId.BeaconLights))
        assertEquals("J", gamepad(ControlId.Flasher))
        assertEquals("U", gamepad(ControlId.LiftDropAxle))
        assertEquals("G", gamepad(ControlId.GarageManager))
    }

    @Test
    fun `controls missing from both maps stay unbound`() {
        assertEquals("-", gamepad(ControlId.AudioFavorite))
        assertEquals("-", keyboard(ControlId.AudioFavorite))
    }

    /// TODO.md Dashboard 4: the camera pad's directions and recenter default to
    /// the `auto` alias — the desktop's InputMapper owns those keys (Numpad8,
    /// ArrowUp, ...), so pressing a pad cell must not ask for a keybind first.
    @Test
    fun `camera pad keys default to the auto alias, not a manual keybind`() {
        val padControls = ControlId.entries.filter { it.wireValue.startsWith("camera_pad_") }
        assertTrue("the pad has controls to alias", padControls.isNotEmpty())

        val gate = DashboardSendGate(send = { _, _ -> }, bindingFor = { keyboard(it) },
            scope = CoroutineScope(Dispatchers.Unconfined),
        )
        for (control in padControls) {
            assertEquals("${control.wireValue} keyboard", "auto", keyboard(control))
            assertEquals("${control.wireValue} gamepad", "auto", gamepad(control))
            assertTrue("${control.wireValue} sends on the first press", gate.shouldSend(control))
        }
    }
}
