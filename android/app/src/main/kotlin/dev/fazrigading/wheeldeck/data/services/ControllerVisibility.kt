package dev.fazrigading.wheeldeck.data.services

/// Which optional inputs are shown on the driving screen. Steering Wheel,
/// Accelerator, and Brake are always shown.
data class ControllerVisibility(
    val showClutch: Boolean,
    val showDashboard: Boolean,
) {
    companion object {
        const val CLUTCH_KEY = "wheeldeck.show_clutch"
        const val DASHBOARD_KEY = "wheeldeck.show_dashboard"
        const val LEGACY_KEY = "wheeldeck.controller_type"

        /// Clutch off, dashboard on — what a fresh install drives.
        val fallback = ControllerVisibility(showClutch = false, showDashboard = true)

        /// Legacy 5-way values mapped to visibility pairs; an unknown value
        /// maps to [fallback].
        private val legacy = mapOf(
            "steeringOnly" to ControllerVisibility(showClutch = false, showDashboard = false),
            "steering3Pedals" to ControllerVisibility(showClutch = true, showDashboard = false),
            "steering2Pedals" to ControllerVisibility(showClutch = false, showDashboard = false),
            "steeringDashboard" to ControllerVisibility(showClutch = false, showDashboard = true),
            "full" to ControllerVisibility(showClutch = true, showDashboard = true),
        )

        fun fromLegacy(value: String) = legacy[value] ?: fallback
    }
}
