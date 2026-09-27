package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.PedalType

/// Left or Right screen placement for a pedal.
enum class PedalSide(val wireValue: String) {
    Left("left"),
    Right("right");

    companion object {
        fun fromWireValue(value: String?): PedalSide =
            entries.firstOrNull { it.wireValue == value } ?: Right
    }
}

/// Per-pedal screen placement, replacing the fixed pedal layout variants.
data class PedalSides(val sides: Map<PedalType, PedalSide> = defaults) {

    /// The stored side of [pedal], or its default.
    fun sideOf(pedal: PedalType): PedalSide = sides[pedal] ?: defaults.getValue(pedal)

    companion object {
        const val KEY_PREFIX = "wheeldeck.pedal_side."
        const val LEGACY_KEY = "wheeldeck.pedal_layout"

        /// Accelerator and brake right, clutch left — what a fresh install drives.
        val defaults: Map<PedalType, PedalSide> = mapOf(
            PedalType.Accelerator to PedalSide.Right,
            PedalType.Brake to PedalSide.Right,
            PedalType.Clutch to PedalSide.Left,
        )

        /// Legacy layout variants mapped to per-pedal sides; `layoutA` mirrors the
        /// defaults.
        private val legacy = mapOf(
            "layoutA" to defaults,
            "layoutB" to mapOf(
                PedalType.Accelerator to PedalSide.Right,
                PedalType.Brake to PedalSide.Left,
                PedalType.Clutch to PedalSide.Left,
            ),
            "layoutC" to mapOf(
                PedalType.Accelerator to PedalSide.Right,
                PedalType.Brake to PedalSide.Right,
            ),
            "layoutD" to mapOf(
                PedalType.Accelerator to PedalSide.Right,
                PedalType.Brake to PedalSide.Left,
            ),
        )

        fun defaults() = PedalSides()

        fun key(pedal: PedalType) = "$KEY_PREFIX${pedal.name.lowercase()}"

        fun fromLegacy(value: String) = PedalSides(legacy[value] ?: defaults)
    }
}
