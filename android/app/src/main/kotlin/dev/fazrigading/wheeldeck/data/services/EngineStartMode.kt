package dev.fazrigading.wheeldeck.data.services

/// How the engine-start control fires: hold-to-confirm or single press.
enum class EngineStartMode(val wireValue: String, val label: String) {
    HoldConfirm("hold_confirm", "Hold to confirm"),
    SinglePress("single_press", "Single press");

    companion object {
        const val KEY = "wheeldeck.engine_start_mode"
        val fallback = HoldConfirm

        fun fromWireValue(value: String?): EngineStartMode =
            entries.firstOrNull { it.wireValue == value } ?: fallback
    }
}
