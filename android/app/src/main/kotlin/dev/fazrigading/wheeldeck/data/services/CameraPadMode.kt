package dev.fazrigading.wheeldeck.data.services

/// Which key set the rotatable camera pad sends: the numpad block or the
/// arrow keys. The pad itself is the switch surface — a three-second hold on
/// its center cell toggles the mode (REQ-017).
enum class CameraPadMode(val wireValue: String) {
    Numpad("numpad"),
    Arrow("arrow");

    /// The other mode; the pad's center hold switches to it.
    val other: CameraPadMode get() = if (this == Numpad) Arrow else Numpad

    companion object {
        const val KEY = "wheeldeck.camera_pad_mode"
        val fallback = Numpad

        fun fromWireValue(value: String?): CameraPadMode =
            entries.firstOrNull { it.wireValue == value } ?: fallback
    }
}
