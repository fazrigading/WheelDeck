package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.ControllerVisibility
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.SettingsStore
import dev.fazrigading.wheeldeck.data.services.SpringBack
import dev.fazrigading.wheeldeck.data.services.WheelMode

/// Single source of truth for driving settings: mapping, visibility, wheel
/// mode, rotation degrees, and the rest of the persisted toggles.
///
/// Every getter applies the ported default when the key was never written, so
/// callers never see a null. Bindings, pedal sides, and reset land with Task 12.
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
}
