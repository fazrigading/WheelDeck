package dev.fazrigading.wheeldeck.data.services

/// Which camera control the rotatable camera pad renders. The D-pad is the
/// dashboard's pad and stays the default; Simple and Analog arrive with their
/// own issues.
enum class CameraControlType(val wireValue: String, val label: String) {
    Dpad("dpad", "D-pad"),
    Simple("simple", "Simple"),
    Analog("analog", "Analog");

    companion object {
        const val KEY = "wheeldeck.camera_control_type"
        val fallback = Dpad

        fun fromWireValue(value: String?): CameraControlType =
            entries.firstOrNull { it.wireValue == value } ?: fallback
    }
}
