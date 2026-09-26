package dev.fazrigading.wheeldeck.domain.models

/// Which pedal a pressure belongs to. Mirrors the Flutter `PedalType`.
enum class PedalType {
    Accelerator,
    Brake,
    Clutch,
}

/// Analog pedal pressure snapshot, each 0.0 (rest) .. 1.0 (full press).
data class PedalState(
    val accelerator: Double = 0.0,
    val brake: Double = 0.0,
    val clutch: Double = 0.0,
) {
    /// Pressure of a single pedal.
    operator fun get(pedal: PedalType): Double = when (pedal) {
        PedalType.Accelerator -> accelerator
        PedalType.Brake -> brake
        PedalType.Clutch -> clutch
    }

    /// Copy with one pedal's pressure replaced, the rest untouched.
    fun with(pedal: PedalType, pressure: Double): PedalState = when (pedal) {
        PedalType.Accelerator -> copy(accelerator = pressure)
        PedalType.Brake -> copy(brake = pressure)
        PedalType.Clutch -> copy(clutch = pressure)
    }

    companion object {
        /// All pedals at rest.
        val released = PedalState()
    }
}
