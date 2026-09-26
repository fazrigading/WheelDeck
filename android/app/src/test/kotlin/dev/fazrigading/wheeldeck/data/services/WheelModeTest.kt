package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/// Port of mobile/test/data/services/wheel_mode_test.dart.
class WheelModeTest {

    private fun repository(store: InMemorySettingsStore) = SettingsRepository(store)

    @Test
    fun `fresh install defaults to rotatable`() = runTest {
        assertEquals(WheelMode.Rotatable, repository(InMemorySettingsStore()).getWheelMode())
    }

    @Test
    fun `round-trips gyro`() = runTest {
        val repo = repository(InMemorySettingsStore())

        repo.setWheelMode(WheelMode.Gyro)

        assertEquals(WheelMode.Gyro, repo.getWheelMode())
    }

    @Test
    fun `unknown stored value falls back to rotatable`() = runTest {
        val repo = repository(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to "tilt")))

        assertEquals(WheelMode.Rotatable, repo.getWheelMode())
    }

    @Test
    fun `fresh install defaults to 900 for every preset`() = runTest {
        val repo = repository(InMemorySettingsStore())

        for (preset in GamePreset.entries) {
            assertEquals(900, repo.getRotationDegree(preset))
        }
    }

    @Test
    fun `allowed degrees round-trip per preset independently`() = runTest {
        val repo = repository(InMemorySettingsStore())

        repo.setRotationDegree(GamePreset.Ets2, 270)
        repo.setRotationDegree(GamePreset.Generic, 1800)

        assertEquals(270, repo.getRotationDegree(GamePreset.Ets2))
        assertEquals(1800, repo.getRotationDegree(GamePreset.Generic))
    }

    @Test
    fun `invalid stored degree falls back to 900`() = runTest {
        val repo = repository(
            InMemorySettingsStore(ints = mapOf(RotationDegree.key(GamePreset.Ets2) to 500)),
        )

        assertEquals(900, repo.getRotationDegree(GamePreset.Ets2))
    }

    @Test
    fun `allowed list matches spec`() {
        assertEquals(listOf(180, 270, 900, 1080, 1800, 2520), RotationDegree.allowed)
    }
}
