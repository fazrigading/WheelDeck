package dev.fazrigading.wheeldeck.ui.features.settings.view_models

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import dev.fazrigading.wheeldeck.data.services.CameraControlType
import dev.fazrigading.wheeldeck.data.services.ControllerVisibility
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.PedalSide
import dev.fazrigading.wheeldeck.data.services.PedalSides
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.SpringBack
import dev.fazrigading.wheeldeck.data.services.WheelMode
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/// One settings section, in the order the screen renders it. The set itself is
/// the visibility rule — see [settingsSections].
enum class SettingsSection {
    InputMode,
    GamePreset,
    WheelMode,
    ShowControls,
    CameraControl,
    PedalSides,
    EngineStart,
    DashboardControls,
    KeybindConfiguration,
    Reset,
}

/// Presentation state for the settings page.
data class SettingsUiState(
    val loaded: Boolean = false,
    val mapping: InputMapping = InputMapping.fallback,
    val preset: GamePreset = GamePreset.fallback,
    val wheelMode: WheelMode = WheelMode.fallback,
    val rotationDegree: Int = RotationDegree.FALLBACK,
    val springBack: Boolean = SpringBack.FALLBACK,
    val cameraControlType: CameraControlType = CameraControlType.fallback,
    val engineStartMode: EngineStartMode = EngineStartMode.fallback,
    val visibility: ControllerVisibility = ControllerVisibility.fallback,
    val pedalSides: PedalSides = PedalSides(),
    val visibleExtras: Set<ControlId> = DashboardVisibility.defaults,
    val bindings: Map<ControlId, String> = emptyMap(),
)

/// Which sections the screen shows, in render order.
///
/// Three rules, ported from `settings_screen.dart`:
/// - pedal sides and the extra dashboard controls are gyro-only (REQ-010,
///   REQ-011) — the rotatable layout fixes their placement;
/// - the camera type needs the rotatable grid. The Dart also hides it when the
///   active layout has no camera pad slot, which cannot happen yet: profile
///   selection and the non-Sequential presets are the custom-layout work
///   (Task 11), so the layout always has one;
/// - the clutch switch is shared, so `ShowControls` always shows.
fun settingsSections(state: SettingsUiState): List<SettingsSection> {
    val rotatable = state.wheelMode == WheelMode.Rotatable
    val gyro = state.wheelMode == WheelMode.Gyro
    return buildList {
        add(SettingsSection.InputMode)
        add(SettingsSection.GamePreset)
        add(SettingsSection.WheelMode)
        add(SettingsSection.ShowControls)
        if (rotatable) add(SettingsSection.CameraControl)
        if (gyro) add(SettingsSection.PedalSides)
        add(SettingsSection.EngineStart)
        if (gyro) add(SettingsSection.DashboardControls)
        add(SettingsSection.KeybindConfiguration)
        add(SettingsSection.Reset)
    }
}

/// Presentation state for the settings page.
///
/// Injects the persisted choices ([SettingsRepository]) and the transport
/// ([ConnectionRepository], which forwards the mapping to the desktop). Owns the
/// binding table so the keybind page and the driving grid agree on what each
/// control is bound to.
class SettingsViewModel(
    private val settingsRepository: SettingsRepository,
    private val connectionRepository: ConnectionRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    /// The binding for [control] in the active mapping mode; unbound controls
    /// read as the dash the send gate treats as unbound.
    fun bindingFor(control: ControlId): String =
        _uiState.value.bindings[control] ?: GamePreset.UNBOUND

    /// Loads every persisted setting. Best-effort: a storage failure leaves the
    /// ported default in place rather than blocking the page.
    suspend fun init() {
        val mapping = load { settingsRepository.getMapping() } ?: InputMapping.fallback
        val preset = load { settingsRepository.getPreset() } ?: GamePreset.fallback
        _uiState.update {
            it.copy(
                mapping = mapping,
                preset = preset,
                wheelMode = load { settingsRepository.getWheelMode() } ?: WheelMode.fallback,
                rotationDegree = load { settingsRepository.getRotationDegree(preset) } ?: RotationDegree.FALLBACK,
                springBack = load { settingsRepository.getSpringBack() } ?: SpringBack.FALLBACK,
                cameraControlType = load { settingsRepository.getCameraControlType() } ?: CameraControlType.fallback,
                engineStartMode = load { settingsRepository.getEngineStartMode() } ?: EngineStartMode.fallback,
                visibility = load { settingsRepository.getVisibility() } ?: ControllerVisibility.fallback,
                pedalSides = load { settingsRepository.getPedalSides() } ?: PedalSides(),
                visibleExtras = (load { settingsRepository.getDashboardVisibility() } ?: DashboardVisibility()).visibleExtras,
                loaded = true,
            )
        }
        loadBindings()
    }

    fun selectMapping(mapping: InputMapping) = persist(
        { settingsRepository.setMapping(mapping) },
        { it.copy(mapping = mapping) },
    ) {
        // The desktop scopes its own tables by mapping, so tell it now.
        connectionRepository.sendMappingMode(mapping.wireValue)
        loadBindings()
    }

    fun selectPreset(preset: GamePreset) = persist(
        { settingsRepository.setPreset(preset) },
        { it.copy(preset = preset) },
    ) {
        // Each preset carries its own rotation degrees.
        val degree = load { settingsRepository.getRotationDegree(preset) } ?: RotationDegree.FALLBACK
        _uiState.update { it.copy(rotationDegree = degree) }
        loadBindings()
    }

    fun selectWheelMode(mode: WheelMode) = persist(
        { settingsRepository.setWheelMode(mode) },
        { it.copy(wheelMode = mode) },
    )

    fun selectRotationDegree(degree: Int) = persist(
        { settingsRepository.setRotationDegree(_uiState.value.preset, degree) },
        { it.copy(rotationDegree = degree) },
    )

    fun selectSpringBack(value: Boolean) = persist(
        { settingsRepository.setSpringBack(value) },
        { it.copy(springBack = value) },
    )

    fun selectCameraControlType(type: CameraControlType) = persist(
        { settingsRepository.setCameraControlType(type) },
        { it.copy(cameraControlType = type) },
    )

    fun selectEngineStartMode(mode: EngineStartMode) = persist(
        { settingsRepository.setEngineStartMode(mode) },
        { it.copy(engineStartMode = mode) },
    )

    fun selectVisibility(visibility: ControllerVisibility) = persist(
        { settingsRepository.setVisibility(visibility) },
        { it.copy(visibility = visibility) },
    )

    fun selectPedalSide(pedal: PedalType, side: PedalSide) = persist(
        { settingsRepository.setPedalSide(pedal, side) },
        { it.copy(pedalSides = PedalSides(it.pedalSides.sides + (pedal to side))) },
    )

    /// Adds or removes an extra from the visible set.
    fun toggleExtraControl(control: ControlId) {
        val next = _uiState.value.visibleExtras.toMutableSet().apply {
            if (!remove(control)) add(control)
        }
        persist({ settingsRepository.setDashboardVisibility(DashboardVisibility(next)) }, { it.copy(visibleExtras = next) })
    }

    /// Restores every setting to the ported default and tells the desktop.
    fun resetToDefaults() {
        viewModelScope.launch {
            load { settingsRepository.resetAll() }
            init()
            connectionRepository.sendMappingMode(_uiState.value.mapping.wireValue)
        }
    }

    /// Stores a binding override for [control] in the active mapping mode. A
    /// blank [value] drops it, so the control falls back to the preset default.
    fun setBinding(control: ControlId, value: String) {
        val isGamepad = _uiState.value.mapping == InputMapping.Gamepad
        viewModelScope.launch {
            load { settingsRepository.setBindingOverride(control, isGamepad, value) }
            loadBindings()
        }
    }


    /// Writes [block] to storage and applies [reduce] to the visible state, then
    /// runs [after] for anything the write implies. A storage failure still
    /// updates the page: a setting the driver flipped should not look stuck.
    private fun persist(
        block: suspend () -> Unit,
        reduce: (SettingsUiState) -> SettingsUiState,
        after: suspend () -> Unit = {},
    ) {
        viewModelScope.launch {
            load { block() }
            _uiState.update(reduce)
            after()
        }
    }

    private suspend fun loadBindings() {
        val mapping = _uiState.value.mapping
        val preset = _uiState.value.preset
        _uiState.update {
            it.copy(
                bindings = ControlId.entries.mapNotNull { control ->
                    load { settingsRepository.resolveBinding(control, mapping, preset) }
                        ?.let { binding -> control to binding }
                }.toMap(),
            )
        }
    }

    /// Best-effort load: storage failures leave the default in place. Cancellation
    /// still propagates.
    private suspend fun <T> load(block: suspend () -> T): T? = try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (_: Exception) {
        null
    }
}
