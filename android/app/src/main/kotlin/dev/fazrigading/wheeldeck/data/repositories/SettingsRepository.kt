package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.CameraControlType
import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.ControllerVisibility
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.PedalSide
import dev.fazrigading.wheeldeck.data.services.PedalSides
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.SettingsStore
import dev.fazrigading.wheeldeck.data.services.SpringBack
import dev.fazrigading.wheeldeck.data.services.WheelMode
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalType

/// Single source of truth for driving settings: mapping, visibility, wheel
/// mode, rotation degrees, and the rest of the persisted toggles.
///
/// Every getter applies the ported default when the key was never written, so
/// callers never see a null. Layout profiles and the camera pad's simple and
/// analog shapes land with the custom-layout work.
class SettingsRepository(private val store: SettingsStore) {

    suspend fun getMapping(): InputMapping =
        InputMapping.fromWireValue(store.loadString(InputMapping.KEY))

    suspend fun setMapping(mapping: InputMapping) =
        store.saveString(InputMapping.KEY, mapping.wireValue)

    suspend fun getPreset(): GamePreset =
        GamePreset.fromWireValue(store.loadString(GamePreset.KEY))

    suspend fun setPreset(preset: GamePreset) =
        store.saveString(GamePreset.KEY, preset.wireValue)

    suspend fun getWheelMode(): WheelMode =
        WheelMode.fromWireValue(store.loadString(WheelMode.KEY))

    suspend fun setWheelMode(mode: WheelMode) =
        store.saveString(WheelMode.KEY, mode.wireValue)

    suspend fun getRotationDegree(preset: GamePreset): Int =
        RotationDegree.resolve(store.loadInt(RotationDegree.key(preset)))

    suspend fun setRotationDegree(preset: GamePreset, degree: Int) {
        require(degree in RotationDegree.allowed) { "Unsupported rotation degree: $degree" }
        store.saveInt(RotationDegree.key(preset), degree)
    }

    suspend fun getSpringBack(): Boolean = store.loadBool(SpringBack.KEY) ?: SpringBack.FALLBACK

    suspend fun setSpringBack(value: Boolean) = store.saveBool(SpringBack.KEY, value)

    suspend fun getCameraPadMode(): CameraPadMode =
        CameraPadMode.fromWireValue(store.loadString(CameraPadMode.KEY))

    suspend fun setCameraPadMode(mode: CameraPadMode) =
        store.saveString(CameraPadMode.KEY, mode.wireValue)

    suspend fun getEngineStartMode(): EngineStartMode =
        EngineStartMode.fromWireValue(store.loadString(EngineStartMode.KEY))

    suspend fun setEngineStartMode(mode: EngineStartMode) =
        store.saveString(EngineStartMode.KEY, mode.wireValue)

    suspend fun getDashboardVisibility(): DashboardVisibility =
        DashboardVisibility.fromWireValues(store.loadStringSet(DashboardVisibility.KEY))

    suspend fun setDashboardVisibility(visibility: DashboardVisibility) =
        store.saveStringSet(DashboardVisibility.KEY, visibility.wireValues())

    /// Reads the controller visibility, migrating a legacy 5-way value on the
    /// way through and removing it.
    suspend fun getVisibility(): ControllerVisibility {
        val legacy = store.loadString(ControllerVisibility.LEGACY_KEY)
        if (legacy != null) {
            val migrated = ControllerVisibility.fromLegacy(legacy)
            setVisibility(migrated)
            store.remove(ControllerVisibility.LEGACY_KEY)
            return migrated
        }
        val clutch = store.loadBool(ControllerVisibility.CLUTCH_KEY)
        val dashboard = store.loadBool(ControllerVisibility.DASHBOARD_KEY)
        if (clutch == null && dashboard == null) return ControllerVisibility.fallback
        return ControllerVisibility(
            showClutch = clutch ?: ControllerVisibility.fallback.showClutch,
            showDashboard = dashboard ?: ControllerVisibility.fallback.showDashboard,
        )
    }

    suspend fun setVisibility(visibility: ControllerVisibility) {
        store.saveBool(ControllerVisibility.CLUTCH_KEY, visibility.showClutch)
        store.saveBool(ControllerVisibility.DASHBOARD_KEY, visibility.showDashboard)
    }

    /// Reads a per-mode binding override, or null when the control still uses the
    /// game preset's default.
    suspend fun getBindingOverride(control: ControlId, isGamepad: Boolean): String? =
        store.loadString(bindingKey(control, isGamepad))?.takeIf { it.isNotEmpty() }

    /// Stores a per-mode binding override. A blank value clears it, so the
    /// control falls back to the preset default.
    suspend fun setBindingOverride(control: ControlId, isGamepad: Boolean, value: String) {
        val key = bindingKey(control, isGamepad)
        if (value.isBlank()) store.remove(key) else store.saveString(key, value.trim())
    }


    /// The camera control type the rotatable pad renders.
    suspend fun getCameraControlType(): CameraControlType =
        CameraControlType.fromWireValue(store.loadString(CameraControlType.KEY))

    suspend fun setCameraControlType(type: CameraControlType) =
        store.saveString(CameraControlType.KEY, type.wireValue)

    /// The per-pedal screen placement, migrating a legacy 4-way layout on the
    /// way through and removing it.
    suspend fun getPedalSides(): PedalSides {
        val legacy = store.loadString(PedalSides.LEGACY_KEY)
        if (legacy != null) {
            val migrated = PedalSides.fromLegacy(legacy)
            setPedalSides(migrated)
            store.remove(PedalSides.LEGACY_KEY)
            return migrated
        }
        val stored = PedalType.entries.mapNotNull { pedal ->
            store.loadString(PedalSides.key(pedal))
                ?.let { PedalSide.fromWireValue(it).let { side -> pedal to side } }
        }.toMap()
        return PedalSides(stored)
    }

    suspend fun setPedalSides(sides: PedalSides) {
        for (pedal in PedalType.entries) {
            store.saveString(PedalSides.key(pedal), sides.sideOf(pedal).wireValue)
        }
    }

    /// Moves one pedal to [side], leaving the others where they are.
    suspend fun setPedalSide(pedal: PedalType, side: PedalSide) =
        setPedalSides(PedalSides(getPedalSides().sides + (pedal to side)))

    /// The effective binding for [control]: a stored override for the active
    /// mapping mode, else the game preset's default. Empty means unbound, and the
    /// send gate then drops the control.
    suspend fun resolveBinding(
        control: ControlId,
        mapping: InputMapping,
        preset: GamePreset,
    ): String {
        val isGamepad = mapping == InputMapping.Gamepad
        return getBindingOverride(control, isGamepad) ?: preset.bindingFor(control, isGamepad)
    }

    /// Drops every override in both mapping modes, restoring the preset defaults.
    suspend fun clearBindingOverrides() {
        for (control in ControlId.entries) {
            store.remove(bindingKey(control, isGamepad = false))
            store.remove(bindingKey(control, isGamepad = true))
        }
    }

    /// Restores every setting to the ported default and drops the overrides.
    /// Mapping returns to [InputMapping.fallback], which is gamepad.
    suspend fun resetAll() {
        setMapping(InputMapping.fallback)
        setPreset(GamePreset.fallback)
        setVisibility(ControllerVisibility.fallback)
        setWheelMode(WheelMode.fallback)
        setSpringBack(SpringBack.FALLBACK)
        setCameraPadMode(CameraPadMode.fallback)
        setEngineStartMode(EngineStartMode.fallback)
        setCameraControlType(CameraControlType.fallback)
        setDashboardVisibility(DashboardVisibility())
        setPedalSides(PedalSides.defaults())
        for (preset in GamePreset.entries) setRotationDegree(preset, RotationDegree.FALLBACK)
        clearBindingOverrides()
    }

    companion object {
        /// The override key, encoding the mapping mode so the two are stored
        /// independently.
        fun bindingKey(control: ControlId, isGamepad: Boolean) =
            "wheeldeck.binding.${if (isGamepad) "gamepad" else "keyboard"}.${control.wireValue}"
    }
}
