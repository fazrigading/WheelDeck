package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InMemorySettingsStore
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.SettingsStore
import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/// The per-mode binding overrides behind the Keybind Configuration page, and the
/// resolution order the driving view uses: a stored override wins over the game
/// preset, and the two mapping modes are stored independently.
class BindingOverridesTest {

    private fun repository(store: SettingsStore = InMemorySettingsStore()) = SettingsRepository(store)

    @Test
    fun `an unset control has no override`() = runTest {
        assertNull(repository().getBindingOverride(ControlId.Horn, isGamepad = false))
    }

    @Test
    fun `an override round-trips per mapping mode`() = runTest {
        val repo = repository()

        repo.setBindingOverride(ControlId.Horn, isGamepad = false, value = "F7")

        assertEquals("F7", repo.getBindingOverride(ControlId.Horn, isGamepad = false))
        assertNull(repo.getBindingOverride(ControlId.Horn, isGamepad = true))
    }

    @Test
    fun `a blank override clears the key`() = runTest {
        val repo = repository()
        repo.setBindingOverride(ControlId.Horn, isGamepad = false, value = "F7")

        repo.setBindingOverride(ControlId.Horn, isGamepad = false, value = "")

        assertNull(repo.getBindingOverride(ControlId.Horn, isGamepad = false))
    }


    @Test
    fun `the stored key encodes the mode and the wire value`() = runTest {
        val store = InMemorySettingsStore()
        repository(store).setBindingOverride(ControlId.Horn, isGamepad = true, value = "LeftThumb")

        assertEquals("LeftThumb", store.loadString(SettingsRepository.bindingKey(ControlId.Horn, isGamepad = true)))
        assertEquals(
            "wheeldeck.binding.gamepad.horn",
            SettingsRepository.bindingKey(ControlId.Horn, isGamepad = true),
        )
        assertEquals(
            "wheeldeck.binding.keyboard.horn",
            SettingsRepository.bindingKey(ControlId.Horn, isGamepad = false),
        )
    }

    @Test
    fun `the preset default is the fallback when no override is stored`() = runTest {
        val repo = repository()

        assertEquals("H", repo.resolveBinding(ControlId.Horn, InputMapping.Keyboard, GamePreset.Ets2))
        assertEquals("LeftThumb", repo.resolveBinding(ControlId.Horn, InputMapping.Gamepad, GamePreset.Ets2))
    }

    @Test
    fun `an override wins over the preset default`() = runTest {
        val repo = repository()
        repo.setBindingOverride(ControlId.Horn, isGamepad = false, value = "F9")

        assertEquals("F9", repo.resolveBinding(ControlId.Horn, InputMapping.Keyboard, GamePreset.Ets2))
        // The other mode is untouched.
        assertEquals("LeftThumb", repo.resolveBinding(ControlId.Horn, InputMapping.Gamepad, GamePreset.Ets2))
    }

    @Test
    fun `a control with no default stays unbound`() = runTest {
        assertEquals(
            GamePreset.UNBOUND,
            repository().resolveBinding(ControlId.AudioFavorite, InputMapping.Gamepad, GamePreset.Ets2),
        )
    }
}
