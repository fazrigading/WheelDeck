package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.CameraControlType
import dev.fazrigading.wheeldeck.data.services.InMemorySettingsStore
import dev.fazrigading.wheeldeck.data.services.PedalSide
import dev.fazrigading.wheeldeck.data.services.PedalSides
import dev.fazrigading.wheeldeck.domain.models.PedalType
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// The settings Task 13 added: the onboarding flag, the per-pedal sides with
/// their legacy-layout migration, and the camera control type.
class OnboardingAndSettingsStoreTest {

    private fun repository(store: InMemorySettingsStore = InMemorySettingsStore()) = SettingsRepository(store)

    @Test
    fun `onboarding is incomplete on a fresh install`() = runTest {
        assertFalse(OnboardingRepository(InMemorySettingsStore()).isComplete())
    }

    @Test
    fun `onboarding completion is persisted`() = runTest {
        val repo = OnboardingRepository(InMemorySettingsStore())

        repo.setComplete()

        assertTrue(repo.isComplete())
    }

    @Test
    fun `pedal sides default to the Dart defaults`() = runTest {
        val sides = repository().getPedalSides()

        assertEquals(PedalSide.Right, sides.sideOf(PedalType.Accelerator))
        assertEquals(PedalSide.Right, sides.sideOf(PedalType.Brake))
        assertEquals(PedalSide.Left, sides.sideOf(PedalType.Clutch))
    }

    @Test
    fun `a pedal side round-trips`() = runTest {
        val repo = repository()

        repo.setPedalSide(PedalType.Brake, PedalSide.Left)

        assertEquals(PedalSide.Left, repo.getPedalSides().sideOf(PedalType.Brake))
        assertEquals(PedalSide.Right, repo.getPedalSides().sideOf(PedalType.Accelerator))
    }

    @Test
    fun `a legacy pedal layout migrates to sides and is removed`() = runTest {
        val store = InMemorySettingsStore(strings = mapOf(PedalSides.LEGACY_KEY to "layoutD"))

        val sides = repository(store).getPedalSides()

        // layoutD: accelerator right, brake left, clutch absent (falls back).
        assertEquals(PedalSide.Right, sides.sideOf(PedalType.Accelerator))
        assertEquals(PedalSide.Left, sides.sideOf(PedalType.Brake))
        assertEquals(PedalSide.Left, sides.sideOf(PedalType.Clutch))
        assertNull(store.loadString(PedalSides.LEGACY_KEY))
    }

    @Test
    fun `an unknown legacy layout falls back to the defaults`() = runTest {
        val store = InMemorySettingsStore(strings = mapOf(PedalSides.LEGACY_KEY to "layoutZ"))

        val sides = repository(store).getPedalSides()

        assertEquals(PedalSides.defaults().sides, sides.sides)
    }

    @Test
    fun `the camera control type defaults to the d-pad`() = runTest {
        assertEquals(CameraControlType.Dpad, repository().getCameraControlType())
    }

    @Test
    fun `the camera control type round-trips`() = runTest {
        val repo = repository()

        repo.setCameraControlType(CameraControlType.Simple)

        assertEquals(CameraControlType.Simple, repo.getCameraControlType())
    }

    @Test
    fun `an unknown stored camera type falls back to the d-pad`() = runTest {
        val store = InMemorySettingsStore(strings = mapOf(CameraControlType.KEY to "trackball"))

        assertEquals(CameraControlType.Dpad, repository(store).getCameraControlType())
    }
}
