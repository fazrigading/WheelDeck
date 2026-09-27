package dev.fazrigading.wheeldeck.ui.features.settings.view_models

import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import dev.fazrigading.wheeldeck.data.services.CameraControlType
import dev.fazrigading.wheeldeck.data.services.ControllerVisibility
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InMemorySettingsStore
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.PedalSide
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.SpringBack
import dev.fazrigading.wheeldeck.data.services.WheelDeckClient
import dev.fazrigading.wheeldeck.data.services.WheelMode
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/// Port of mobile/test/ui/features/settings/settings_screen_test.dart. That
/// suite is a widget test, so what is asserted here is the section-visibility
/// rule it exercises — which sections the wheel mode and the active layout
/// decide — not the rendered text. The four layout-profile cases in the Dart
/// suite are deferred with the layout editor (see tasks/plan.md Task 13).
@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {

    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun TestScope.viewModel(store: InMemorySettingsStore = InMemorySettingsStore()) = SettingsViewModel(
        settingsRepository = SettingsRepository(store),
        connectionRepository = ConnectionRepository(WheelDeckClient(deviceId = "test", scope = this)),
    )

    private fun storeWithWheelMode(mode: WheelMode) = InMemorySettingsStore(
        strings = mapOf(WheelMode.KEY to mode.wireValue),
    )

    @Test
    fun `gyro mode shows pedal sides and dashboard controls`() = runTest(dispatcher) {
        val vm = viewModel(storeWithWheelMode(WheelMode.Gyro))
        vm.init()
        advanceUntilIdle()

        val sections = settingsSections(vm.uiState.value)

        assertTrue(sections.contains(SettingsSection.PedalSides))
        assertTrue(sections.contains(SettingsSection.DashboardControls))
    }

    @Test
    fun `rotatable mode hides pedal sides and dashboard controls`() = runTest(dispatcher) {
        val vm = viewModel(storeWithWheelMode(WheelMode.Rotatable))
        vm.init()
        advanceUntilIdle()

        val sections = settingsSections(vm.uiState.value)

        assertFalse(sections.contains(SettingsSection.PedalSides))
        assertFalse(sections.contains(SettingsSection.DashboardControls))
    }

    @Test
    fun `both modes keep the clutch switch and the rest`() = runTest(dispatcher) {
        for (mode in WheelMode.entries) {
            val vm = viewModel(storeWithWheelMode(mode))
            vm.init()
            advanceUntilIdle()

            val sections = settingsSections(vm.uiState.value)

            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.ShowControls))
            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.InputMode))
            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.GamePreset))
            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.WheelMode))
            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.EngineStart))
            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.KeybindConfiguration))
            assertEquals(mode.wireValue, true, sections.contains(SettingsSection.Reset))
        }
    }


    @Test
    fun `the camera section shows in rotatable mode`() = runTest(dispatcher) {
        val vm = viewModel(storeWithWheelMode(WheelMode.Rotatable))
        vm.init()
        advanceUntilIdle()

        assertTrue(settingsSections(vm.uiState.value).contains(SettingsSection.CameraControl))
    }

    /// The Dart also hides this when the active layout has no camera pad slot.
    /// That cannot happen yet — profile selection and the non-Sequential presets
    /// are the deferred custom-layout work — so the rule is rotatable-only.
    @Test
    fun `the camera section is rotatable-only`() = runTest(dispatcher) {
        for (mode in WheelMode.entries) {
            val vm = viewModel(storeWithWheelMode(mode))
            vm.init()
            advanceUntilIdle()

            assertEquals(
                mode.wireValue,
                mode == WheelMode.Rotatable,
                settingsSections(vm.uiState.value).contains(SettingsSection.CameraControl),
            )
        }
    }

    @Test
    fun `init resolves the persisted settings`() = runTest(dispatcher) {
        val vm = viewModel(
            InMemorySettingsStore(
                strings = mapOf(
                    WheelMode.KEY to WheelMode.Gyro.wireValue,
                    InputMapping.KEY to InputMapping.Keyboard.wireValue,
                    EngineStartMode.KEY to EngineStartMode.SinglePress.wireValue,
                    GamePreset.KEY to GamePreset.Generic.wireValue,
                    CameraControlType.KEY to CameraControlType.Analog.wireValue,
                ),
                bools = mapOf(ControllerVisibility.CLUTCH_KEY to true, SpringBack.KEY to false),
                ints = mapOf(RotationDegree.key(GamePreset.Generic) to 1080),
            ),
        )

        vm.init()
        advanceUntilIdle()

        val state = vm.uiState.value
        assertTrue(state.loaded)
        assertEquals(WheelMode.Gyro, state.wheelMode)
        assertEquals(InputMapping.Keyboard, state.mapping)
        assertEquals(EngineStartMode.SinglePress, state.engineStartMode)
        assertEquals(GamePreset.Generic, state.preset)
        assertEquals(CameraControlType.Analog, state.cameraControlType)
        assertEquals(1080, state.rotationDegree)
        assertFalse(state.springBack)
        assertTrue(state.visibility.showClutch)
        assertEquals(PedalSide.Left, state.pedalSides.sideOf(PedalType.Clutch))
        assertEquals(DashboardVisibility.defaults, state.visibleExtras)
    }

    @Test
    fun `a binding override wins over the preset default, per mapping mode`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.init()
        advanceUntilIdle()

        // Default mapping is gamepad; audioFavorite has no default in either.
        assertEquals(GamePreset.UNBOUND, vm.bindingFor(ControlId.AudioFavorite))

        vm.setBinding(ControlId.AudioFavorite, "F12")
        advanceUntilIdle()
        assertEquals("F12", vm.bindingFor(ControlId.AudioFavorite))

        // The keyboard mode is untouched by a gamepad override.
        vm.selectMapping(InputMapping.Keyboard)
        advanceUntilIdle()
        assertEquals(GamePreset.UNBOUND, vm.bindingFor(ControlId.AudioFavorite))
    }

    @Test
    fun `selecting a mapping re-resolves the bindings`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.init()
        advanceUntilIdle()

        assertEquals("LeftThumb", vm.bindingFor(ControlId.Horn))

        vm.selectMapping(InputMapping.Keyboard)
        advanceUntilIdle()

        assertEquals("H", vm.bindingFor(ControlId.Horn))
    }

    @Test
    fun `selecting a preset swaps the defaults underneath the overrides`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.init()
        advanceUntilIdle()
        vm.setBinding(ControlId.Horn, "F9")
        advanceUntilIdle()

        // The override survives the preset change.
        vm.selectPreset(GamePreset.Generic)
        advanceUntilIdle()

        assertEquals(GamePreset.Generic, vm.uiState.value.preset)
        assertEquals("F9", vm.bindingFor(ControlId.Horn))
    }

    @Test
    fun `toggling an extra control flips its visibility`() = runTest(dispatcher) {
        val vm = viewModel()
        vm.init()
        advanceUntilIdle()
        val before = vm.uiState.value.visibleExtras

        vm.toggleExtraControl(ControlId.AirHorn)
        advanceUntilIdle()

        assertEquals(before + ControlId.AirHorn, vm.uiState.value.visibleExtras)

        vm.toggleExtraControl(ControlId.AirHorn)
        advanceUntilIdle()

        assertEquals(before, vm.uiState.value.visibleExtras)
    }

    @Test
    fun `reset restores every default and drops the overrides`() = runTest(dispatcher) {
        val vm = viewModel(
            InMemorySettingsStore(
                strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue),
                bools = mapOf(SpringBack.KEY to false),
            ),
        )
        vm.init()
        advanceUntilIdle()
        vm.setBinding(ControlId.Horn, "F9")
        advanceUntilIdle()

        vm.resetToDefaults()
        advanceUntilIdle()

        val state = vm.uiState.value
        assertEquals(WheelMode.fallback, state.wheelMode)
        assertEquals(InputMapping.fallback, state.mapping)
        assertEquals(GamePreset.fallback, state.preset)
        assertEquals(EngineStartMode.fallback, state.engineStartMode)
        assertEquals(CameraControlType.fallback, state.cameraControlType)
        assertEquals(RotationDegree.FALLBACK, state.rotationDegree)
        assertEquals(SpringBack.FALLBACK, state.springBack)
        assertEquals(ControllerVisibility.fallback, state.visibility)
        assertEquals(PedalSide.Right, state.pedalSides.sideOf(PedalType.Brake))
        assertEquals(GamePreset.Ets2.bindingFor(ControlId.Horn, isGamepad = true), vm.bindingFor(ControlId.Horn))
    }
}
