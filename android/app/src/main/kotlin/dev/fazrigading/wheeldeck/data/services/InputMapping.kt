package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.MappingMode

/// How dashboard buttons are interpreted by the desktop.
/// Persistence lands with the settings store (plan Task 13).
enum class InputMapping(val wireValue: String) {
    /** Dashboard controls become simulated keyboard presses (ETS2 defaults). */
    Keyboard("keyboard"),

    /** Dashboard controls become virtual-controller button presses. */
    Gamepad("gamepad");

    companion object {
        val fallback = Gamepad

        fun fromWireValue(value: String?): InputMapping =
            entries.firstOrNull { it.wireValue == value } ?: fallback

        fun fromMappingMode(mode: MappingMode): InputMapping = valueOf(mode.name)
    }
}
