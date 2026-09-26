package dev.fazrigading.wheeldeck.ui.features.driving.view_models

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.ControllerVisibility
import dev.fazrigading.wheeldeck.data.services.DashboardInput
import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.SteeringSensor
import dev.fazrigading.wheeldeck.data.services.SpringBack
import dev.fazrigading.wheeldeck.data.services.WheelMode
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalState
import dev.fazrigading.wheeldeck.domain.models.PedalType
import dev.fazrigading.wheeldeck.domain.models.SteeringState
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.abs

/// Presentation state for the driving view: steering angle, pedal pressures,
/// the calibration gate, and the driving modes.
data class DrivingUiState(
    /// Gyro steering. Stays [SteeringState.centered] in rotatable mode, where
    /// [DrivingViewModel.rotatableAngle] owns the angle instead.
    val steering: SteeringState = SteeringState.centered,
    val pedals: PedalState = PedalState.released,
    /// True while input is gated behind a re-confirmed steering center.
    val awaitingCalibration: Boolean = false,
    val isRotatable: Boolean = WheelMode.fallback == WheelMode.Rotatable,
    val rotationDegree: Int = RotationDegree.FALLBACK,
    val springBack: Boolean = SpringBack.FALLBACK,
    val cameraPadMode: CameraPadMode = CameraPadMode.fallback,
    val engineStartMode: EngineStartMode = EngineStartMode.fallback,
    val visibleExtras: Set<ControlId> = DashboardVisibility.defaults,
    val visibility: ControllerVisibility = ControllerVisibility.fallback,
)

/// Presentation state for the driving view.
///
/// Injects the transport ([ConnectionRepository]), the settings
/// ([SettingsRepository]), and the two input sources ([SteeringSensor],
/// [PedalInput]) plus the stateless [DashboardInput] event forwarder. Owns no
/// transport framing: the view collects [uiState] and calls the commands below.
class DrivingViewModel(
    private val connectionRepository: ConnectionRepository,
    private val settingsRepository: SettingsRepository,
    private val sensor: SteeringSensor,
    private val pedals: PedalInput,
    private val dashboardInput: DashboardInput = DashboardInput(),
) : ViewModel() {

    private val _uiState = MutableStateFlow(DrivingUiState())
    val uiState: StateFlow<DrivingUiState> = _uiState.asStateFlow()

    /// Phone-held send gate on the control path.
    val sendGate = DashboardSendGate(
        send = { control, action ->
            connectionRepository.sendButtonEvent(control.wireValue, action.wireValue)
        },
        // Unbound until Task 12 resolves the preset defaults and the stored
        // per-mode overrides; unbound controls send nothing, which is the safe
        // side of that gap.
        bindingFor = { "" },
        scope = viewModelScope,
    )

    /// Rotatable-wheel angle, deliberately kept out of [uiState]: the wheel
    /// owns its drag visuals, and publishing every frame would rebuild the
    /// whole block grid.
    var rotatableAngle: Double = 0.0
        private set

    private var cameraX = 0.0
    private var cameraY = 0.0
    private var draggingWheel = false
    private var dragBase = 0.0

    init {
        sensor.onAngleChanged(::onSensorAngle)
        sensor.start(viewModelScope)
        viewModelScope.launch { pedals.state.collect(::onPedals) }
        dashboardInput.onControlActivated { control, action -> sendGate.handle(control, action) }
    }

    /// Loads the persisted driving settings and applies the mapping on the
    /// desktop. Every load is best-effort: driving still works when storage is
    /// unavailable.
    suspend fun init() {
        load { settingsRepository.getMapping() }?.let {
            connectionRepository.sendMappingMode(it.wireValue)
        }
        loadWheelState()
        loadDashboardState()
        load { settingsRepository.getVisibility() }?.let { visibility ->
            _uiState.update { it.copy(visibility = visibility) }
        }
        if (_uiState.value.isRotatable) setAwaitingCalibration(false)
    }

    /// Re-reads everything the settings screen can change. Rotatable steering
    /// cannot drift, so switching into it clears the gate.
    suspend fun refreshSettings() {
        loadWheelState()
        loadDashboardState()
        load { settingsRepository.getVisibility() }?.let { visibility ->
            _uiState.update { it.copy(visibility = visibility) }
        }
        if (_uiState.value.isRotatable) setAwaitingCalibration(false)
    }

    /// The camera pad's center hold switches the key set; the pad is the
    /// switch surface (REQ-017). Persists in the view model scope, so a
    /// Composable can call it straight from the gesture.
    fun toggleCameraPadMode() {
        val next = _uiState.value.cameraPadMode.other
        _uiState.update { it.copy(cameraPadMode = next) }
        viewModelScope.launch { load { settingsRepository.setCameraPadMode(next) } }
    }

    /// Syncs the calibration gate. Rotatable steering cannot drift, so the gate
    /// never engages there.
    fun setAwaitingCalibration(value: Boolean) {
        val next = if (_uiState.value.isRotatable) false else value
        if (_uiState.value.awaitingCalibration == next) return
        _uiState.update { it.copy(awaitingCalibration = next) }
    }

    /// Re-centers the sensor and re-opens input.
    fun confirmCalibration() {
        sensor.setCenter()
        setAwaitingCalibration(false)
    }

    /// Manual zeroing for drift or a moved phone — does not touch the gate.
    fun recalibrate() {
        sensor.setCenter()
        _uiState.update { it.copy(steering = SteeringState.centered) }
    }

    /// Sets the pressure directly while the user drags a pedal bar.
    fun setPedalPressure(pedal: PedalType, pressure: Double) = pedals.setPressure(pedal, pressure)

    /// Releases a pedal so it springs back toward rest.
    fun releasePedal(pedal: PedalType) = pedals.release(pedal)

    /// Starts a horizontal-drag fallback gesture on the wheel.
    fun onWheelDragStart() {
        draggingWheel = true
        dragBase = currentAngle()
    }

    /// Applies a horizontal-drag delta (~200 logical px = full lock). In
    /// rotatable mode the drag feeds the rotatable angle, which is the one the
    /// state frame carries.
    fun onWheelDragUpdate(dx: Double) {
        val angle = (dragBase + dx / 200).coerceIn(-1.0, 1.0)
        if (_uiState.value.isRotatable) {
            rotatableAngle = angle
        } else {
            _uiState.update { it.copy(steering = SteeringState(angle)) }
        }
        sendState()
    }

    /// Ends the drag gesture and recenters the gyro on the dragged angle.
    fun onWheelDragEnd() {
        draggingWheel = false
        dragBase = currentAngle()
        sensor.setCenter()
    }

    /// Applies rotatable-wheel steering. Bypasses the gyro deadband so finger
    /// feedback stays 1:1; always transmits, so spring-back to zero is sent.
    fun setRotatableSteering(angle: Double) {
        rotatableAngle = angle.coerceIn(-1.0, 1.0)
        sendState()
    }

    /// Reports analog camera look. Nothing renders these values, so the visible
    /// state is left alone.
    fun setAnalogCamera(x: Double, y: Double) {
        cameraX = x.coerceIn(-1.0, 1.0)
        cameraY = y.coerceIn(-1.0, 1.0)
        sendState()
    }

    /// Clears the calibration gate and disconnects.
    fun disconnect() {
        setAwaitingCalibration(false)
        connectionRepository.disconnect()
    }

    override fun onCleared() {
        sensor.stop()
        sendGate.dispose()
        pedals.dispose()
        super.onCleared()
    }

    private suspend fun loadWheelState() {
        val mode = load { settingsRepository.getWheelMode() } ?: WheelMode.fallback
        val preset = load { settingsRepository.getPreset() } ?: GamePreset.fallback
        val degree = load { settingsRepository.getRotationDegree(preset) } ?: RotationDegree.FALLBACK
        val springBack = load { settingsRepository.getSpringBack() } ?: SpringBack.FALLBACK
        val cameraPadMode = load { settingsRepository.getCameraPadMode() } ?: CameraPadMode.fallback
        _uiState.update {
            it.copy(
                isRotatable = mode == WheelMode.Rotatable,
                rotationDegree = degree,
                springBack = springBack,
                cameraPadMode = cameraPadMode,
            )
        }
    }

    private suspend fun loadDashboardState() {
        val engineStart = load { settingsRepository.getEngineStartMode() } ?: EngineStartMode.fallback
        val visibility = load { settingsRepository.getDashboardVisibility() } ?: DashboardVisibility()
        _uiState.update { it.copy(engineStartMode = engineStart, visibleExtras = visibility.visibleExtras) }
    }

    private fun onSensorAngle(angle: Double) {
        val state = _uiState.value
        if (state.awaitingCalibration || draggingWheel || state.isRotatable) return
        if (abs(state.steering.angle - angle) < 0.002) return
        _uiState.update { it.copy(steering = SteeringState(angle)) }
        sendState()
    }

    private fun onPedals(pedals: PedalState) {
        if (_uiState.value.awaitingCalibration) return
        _uiState.update { it.copy(pedals = pedals) }
        sendState()
    }

    private fun currentAngle() =
        if (_uiState.value.isRotatable) rotatableAngle else _uiState.value.steering.angle

    private fun sendState() {
        val pedals = _uiState.value.pedals
        connectionRepository.sendState(
            steering = currentAngle(),
            accelerator = pedals.accelerator,
            brake = pedals.brake,
            clutch = pedals.clutch,
            cameraX = cameraX,
            cameraY = cameraY,
        )
    }

    /// Best-effort load: storage failures leave the default in place instead of
    /// breaking driving. Cancellation still propagates.
    private suspend fun <T> load(block: suspend () -> T): T? = try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        null
    }
}
