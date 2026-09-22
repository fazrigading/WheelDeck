package dev.fazrigading.wheeldeck.domain.models

/// Normalized steering angle snapshot (-1.0 full left .. 1.0 full right).
data class SteeringState(
    val angle: Double = 0.0,
) {
    companion object {
        val centered = SteeringState()
    }
}
