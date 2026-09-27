package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import dev.fazrigading.wheeldeck.domain.models.ControlId
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/// Port of mobile/test/data/services/dashboard_visibility_test.dart.
class DashboardVisibilityTest {

    private fun repository(store: InMemorySettingsStore = InMemorySettingsStore()) =
        SettingsRepository(store)

    @Test
    fun `EngineStartMode defaults to hold-confirm`() = runTest {
        assertEquals(EngineStartMode.HoldConfirm, repository().getEngineStartMode())
    }

    @Test
    fun `EngineStartMode round-trips single press`() = runTest {
        val repo = repository()

        repo.setEngineStartMode(EngineStartMode.SinglePress)

        assertEquals(EngineStartMode.SinglePress, repo.getEngineStartMode())
    }

    @Test
    fun `unknown engine mode falls back to hold-confirm`() {
        assertEquals(EngineStartMode.HoldConfirm, EngineStartMode.fromWireValue("bogus"))
    }

    @Test
    fun `defaults show gears and engine brake only`() {
        assertEquals(
            setOf(ControlId.GearUp, ControlId.GearDown, ControlId.EngineBrake),
            DashboardVisibility.defaults,
        )
    }

    @Test
    fun `defaults load from empty prefs`() = runTest {
        val loaded = repository().getDashboardVisibility()

        assertEquals(DashboardVisibility.defaults, loaded.visibleExtras)
    }

    @Test
    fun `toggle round-trips through prefs`() = runTest {
        val store = InMemorySettingsStore()
        val repo = repository(store)

        val visibility = repo.getDashboardVisibility().toggled(ControlId.AirHorn)
        repo.setDashboardVisibility(visibility)

        val reloaded = repository(store).getDashboardVisibility()
        assertTrue(reloaded.isVisible(ControlId.AirHorn))
        assertTrue(reloaded.isVisible(ControlId.GearUp))
    }

    @Test
    fun `toggle twice restores the default set`() = runTest {
        val store = InMemorySettingsStore()

        val visibility = repository(store)
            .getDashboardVisibility()
            .toggled(ControlId.AirHorn)
            .toggled(ControlId.AirHorn)

        assertEquals(DashboardVisibility.defaults, visibility.visibleExtras)
    }

    @Test
    fun `core grid controls are never toggleable extras`() {
        val core = DashboardVisibility.coreControls.toSet()

        for (control in DashboardVisibility.toggleable) {
            assertFalse("$control is a core control", control in core)
        }
    }

    @Test
    fun `block E split keeps camera and menu controls out while dashboard info and activate are toggleable`() {
        val toggleable = DashboardVisibility.toggleable

        assertTrue(ControlId.DashboardInfo in toggleable)
        assertTrue(ControlId.Activate in toggleable)
        val excluded = listOf(
            ControlId.CameraInterior,
            ControlId.CameraChasing,
            ControlId.CameraTopdown,
            ControlId.CameraRoof,
            ControlId.CameraLeanout,
            ControlId.NextCamera,
            ControlId.Menu,
            ControlId.WorldMap,
            ControlId.PhotoMode,
        )
        for (control in excluded) {
            assertFalse("$control is excluded", control in toggleable)
        }
    }

    @Test
    fun `comfort and chat batch is toggleable (TASK-049)`() {
        val toggleable = DashboardVisibility.toggleable

        val batch = listOf(
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
        )
        for (control in batch) {
            assertTrue("$control is toggleable", control in toggleable)
        }
    }

    @Test
    fun `unknown stored wire values are dropped`() = runTest {
        val repo = repository(
            InMemorySettingsStore(
                stringSets = mapOf(
                    DashboardVisibility.KEY to setOf("air_horn", "not_a_control"),
                ),
            ),
        )

        assertEquals(setOf(ControlId.AirHorn), repo.getDashboardVisibility().visibleExtras)
    }

    @Test
    fun `controller visibility falls back and migrates a legacy value`() = runTest {
        assertEquals(ControllerVisibility.fallback, repository().getVisibility())

        val store = InMemorySettingsStore(strings = mapOf(ControllerVisibility.LEGACY_KEY to "full"))
        val migrated = repository(store).getVisibility()

        assertEquals(ControllerVisibility(showClutch = true, showDashboard = true), migrated)
        assertEquals(migrated, repository(store).getVisibility())
    }

    @Test
    fun `a half-written visibility keeps the fallback for the missing half`() = runTest {
        val repo = repository(
            InMemorySettingsStore(bools = mapOf(ControllerVisibility.DASHBOARD_KEY to false)),
        )

        val loaded = repo.getVisibility()

        assertEquals(ControllerVisibility(showClutch = false, showDashboard = false), loaded)
    }
}
