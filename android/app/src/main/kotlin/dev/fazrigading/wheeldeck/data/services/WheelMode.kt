package dev.fazrigading.wheeldeck.data.services

/// How steering input is captured on the phone.
enum class WheelMode(val wireValue: String, val label: String) {
    /** Finger-drag circular wheel; N degrees of finger rotation = full lock. */
    Rotatable("rotatable", "Rotatable"),

    /** Phone tilt via gyroscope. */
    Gyro("gyro", "Gyro");

    companion object {
        const val KEY = "wheeldeck.wheel_mode"

        /// Fresh installs drive the rotatable wheel.
        val fallback = Rotatable

        fun fromWireValue(value: String?): WheelMode =
            entries.firstOrNull { it.wireValue == value } ?: fallback
    }
}

/// Finger-rotation range mapping to full lock-to-lock, stored per game preset.
/// Gyro steering ignores degrees.
object RotationDegree {
    val allowed = listOf(180, 270, 900, 1080, 1800, 2520)
    const val FALLBACK = 900
    const val KEY_PREFIX = "wheeldeck.rotation_degree."

    fun key(preset: GamePreset) = "$KEY_PREFIX${preset.wireValue}"

    /// Stored value, or [FALLBACK] when unset or not one of [allowed].
    fun resolve(stored: Int?): Int = if (stored in allowed) stored!! else FALLBACK
}
