package dev.fazrigading.wheeldeck.ui.features.driving.view_models

import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InMemorySettingsStore
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.SteeringSensor
import dev.fazrigading.wheeldeck.data.services.SpringBack
import dev.fazrigading.wheeldeck.data.services.WheelMode
import dev.fazrigading.wheeldeck.data.services.WheelDeckClient
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import kotlin.math.PI

/// Port of mobile/test/ui/features/driving/driving_view_model_test.dart, minus
/// the layout-profile cases (Task 11) and the binding-resolution cases
/// (Task 12) — both assert on code that has not landed yet.
@OptIn(ExperimentalCoroutinesApi::class)
class DrivingViewModelTest {

    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private class Fixture(
        scope: TestScope,
        val settings: InMemorySettingsStore = InMemorySettingsStore(),
    ) {
        val rawAngles = MutableSharedFlow<Double>(extraBufferCapacity = 64)
        val settingsRepository = SettingsRepository(settings)
        val viewModel = DrivingViewModel(
            connectionRepository = ConnectionRepository(WheelDeckClient(deviceId = "test", scope = scope)),
            settingsRepository = settingsRepository,
            sensor = SteeringSensor(rawAngleStream = rawAngles),
            // backgroundScope: cancelled when the test ends, so PedalInput's own
            // job never keeps runTest waiting.
            pedals = PedalInput(scope.backgroundScope, releaseDurationMs = 0),
        )
    }

    private fun TestScope.fixture(settings: InMemorySettingsStore = InMemorySettingsStore()) =
        Fixture(this, settings)

    @Test
    fun `rotatable mode loads mode and degree`() = runTest(dispatcher) {
        val f = fixture(
            InMemorySettingsStore(
                strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue),
                ints = mapOf(RotationDegree.key(GamePreset.Ets2) to 270),
            ),
        )

        f.viewModel.init()
        advanceUntilIdle()

        assertTrue(f.viewModel.uiState.value.isRotatable)
        assertEquals(270, f.viewModel.uiState.value.rotationDegree)
    }

    @Test
    fun `rotatable mode skips the calibration gate`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.setAwaitingCalibration(true)

        assertFalse(f.viewModel.uiState.value.awaitingCalibration)
    }

    @Test
    fun `camera pad mode loads and toggles with persistence`() = runTest(dispatcher) {
        val f = fixture(
            InMemorySettingsStore(
                strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue, CameraPadMode.KEY to CameraPadMode.Arrow.wireValue),
            ),
        )
        f.viewModel.init()
        advanceUntilIdle()
        assertEquals(CameraPadMode.Arrow, f.viewModel.uiState.value.cameraPadMode)

        f.viewModel.toggleCameraPadMode()
        advanceUntilIdle()

        assertEquals(CameraPadMode.Numpad, f.viewModel.uiState.value.cameraPadMode)
        assertEquals(CameraPadMode.Numpad, f.settingsRepository.getCameraPadMode())
    }

    @Test
    fun `rotatable steering is accepted and the gyro is ignored`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.setRotatableSteering(0.5)
        f.rawAngles.tryEmit(0.9)
        runCurrent()

        assertEquals(0.5, f.viewModel.rotatableAngle, 1e-9)
        // The gyro never reaches the visible state in rotatable mode.
        assertEquals(0.0, f.viewModel.uiState.value.steering.angle, 1e-9)
    }

    @Test
    fun `release back to zero clears the rotatable angle`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.setRotatableSteering(0.5)
        f.viewModel.setRotatableSteering(0.0)

        assertEquals(0.0, f.viewModel.rotatableAngle, 1e-9)
    }

    @Test
    fun `rotatable steering clamps beyond full lock`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.setRotatableSteering(4.0)

        assertEquals(1.0, f.viewModel.rotatableAngle, 1e-9)
    }

    @Test
    fun `gyro mode defaults to keeping the calibration gate`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        assertFalse(f.viewModel.uiState.value.isRotatable)
        f.viewModel.setAwaitingCalibration(true)

        assertTrue(f.viewModel.uiState.value.awaitingCalibration)
    }

    @Test
    fun `sensor angles flow through in gyro mode`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.rawAngles.tryEmit(0.3)
        runCurrent()

        // SteeringSensor scales by maxRotationAngle (pi/4).
        assertEquals(0.3 / (PI / 4), f.viewModel.uiState.value.steering.angle, 0.01)
    }

    @Test
    fun `the calibration gate suppresses gyro input until confirmed`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()
        f.viewModel.setAwaitingCalibration(true)

        f.rawAngles.tryEmit(0.4)
        runCurrent()

        assertEquals(0.0, f.viewModel.uiState.value.steering.angle, 1e-9)
    }

    @Test
    fun `confirming calibration re-centers the sensor`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()
        f.rawAngles.tryEmit(0.5)
        runCurrent()
        f.viewModel.setAwaitingCalibration(true)

        f.viewModel.confirmCalibration()

        assertFalse(f.viewModel.uiState.value.awaitingCalibration)
        // The center moved to the held angle, so the same sample now reads straight.
        f.rawAngles.tryEmit(0.5)
        runCurrent()
        assertEquals(0.0, f.viewModel.uiState.value.steering.angle, 1e-9)
    }

    @Test
    fun `pedal pressure reaches the driving state`() = runTest(dispatcher) {
        val f = fixture()
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.setPedalPressure(PedalType.Accelerator, 0.6)
        runCurrent()

        assertEquals(0.6, f.viewModel.uiState.value.pedals.accelerator, 1e-9)
    }

    @Test
    fun `releasing a pedal springs it back to rest`() = runTest(dispatcher) {
        val f = fixture()
        f.viewModel.init()
        advanceUntilIdle()
        f.viewModel.setPedalPressure(PedalType.Brake, 0.9)
        runCurrent()

        f.viewModel.releasePedal(PedalType.Brake)
        runCurrent()

        assertEquals(0.0, f.viewModel.uiState.value.pedals.brake, 1e-9)
    }

    @Test
    fun `wheel drag fallback drives steering while dragging`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.onWheelDragStart()
        f.viewModel.onWheelDragUpdate(100.0)

        assertEquals(0.5, f.viewModel.uiState.value.steering.angle, 1e-9)
    }

    @Test
    fun `the gyro is ignored while the wheel is being dragged`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()
        f.viewModel.onWheelDragStart()

        f.rawAngles.tryEmit(0.4)
        runCurrent()

        assertEquals(0.0, f.viewModel.uiState.value.steering.angle, 1e-9)
    }

    @Test
    fun `recalibrate zeroes steering without touching the gate`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()
        f.rawAngles.tryEmit(0.4)
        runCurrent()
        f.viewModel.setAwaitingCalibration(true)

        f.viewModel.recalibrate()

        assertEquals(0.0, f.viewModel.uiState.value.steering.angle, 1e-9)
        assertTrue(f.viewModel.uiState.value.awaitingCalibration)
    }

    @Test
    fun `refreshSettings picks up a mode switch and clears the gate`() = runTest(dispatcher) {
        val store = InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Gyro.wireValue))
        val f = fixture(store)
        f.viewModel.init()
        advanceUntilIdle()
        f.viewModel.setAwaitingCalibration(true)
        assertTrue(f.viewModel.uiState.value.awaitingCalibration)

        store.saveString(WheelMode.KEY, WheelMode.Rotatable.wireValue)
        f.viewModel.refreshSettings()
        advanceUntilIdle()

        assertTrue(f.viewModel.uiState.value.isRotatable)
        assertFalse(f.viewModel.uiState.value.awaitingCalibration)
    }

    @Test
    fun `dashboard state loads engine mode and visible extras`() = runTest(dispatcher) {
        val f = fixture(
            InMemorySettingsStore(
                strings = mapOf(EngineStartMode.KEY to EngineStartMode.SinglePress.wireValue),
                stringSets = mapOf(DashboardVisibility.KEY to setOf(ControlId.AirHorn.wireValue)),
            ),
        )
        f.viewModel.init()
        advanceUntilIdle()

        assertEquals(EngineStartMode.SinglePress, f.viewModel.uiState.value.engineStartMode)
        assertEquals(setOf(ControlId.AirHorn), f.viewModel.uiState.value.visibleExtras)
    }

    @Test
    fun `loads the spring-back setting`() = runTest(dispatcher) {
        val f = fixture(
            InMemorySettingsStore(
                strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue),
                bools = mapOf(SpringBack.KEY to false),
            ),
        )

        f.viewModel.init()
        advanceUntilIdle()

        assertFalse(f.viewModel.uiState.value.springBack)
    }

    @Test
    fun `rotatable drag feeds the angle the state frame carries`() = runTest(dispatcher) {
        val f = fixture(InMemorySettingsStore(strings = mapOf(WheelMode.KEY to WheelMode.Rotatable.wireValue)))
        f.viewModel.init()
        advanceUntilIdle()

        f.viewModel.onWheelDragStart()
        f.viewModel.onWheelDragUpdate(100.0)

        assertEquals(0.5, f.viewModel.rotatableAngle, 1e-9)
        assertEquals(0.0, f.viewModel.uiState.value.steering.angle, 1e-9)
    }
}
