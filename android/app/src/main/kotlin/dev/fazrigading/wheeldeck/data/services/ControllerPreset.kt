package dev.fazrigading.wheeldeck.data.services

/// Game-specific button presets. Wire values mirror desktop InputMapper
/// defaults (ETS2). The default binding tables land with Task 12.
enum class GamePreset(val wireValue: String, val label: String) {
    Ets2("ets2", "Euro Truck Simulator 2"),
    Generic("generic", "Generic");

    companion object {
        const val KEY = "wheeldeck.game_preset"
        val fallback = Ets2

        fun fromWireValue(value: String?): GamePreset =
            entries.firstOrNull { it.wireValue == value } ?: fallback
    }
}
