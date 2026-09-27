package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ActionType
import dev.fazrigading.wheeldeck.domain.models.ControlId

/// Receives discrete dashboard control events from the UI.
class DashboardInput {
    private var onControlActivated: ((ControlId, ActionType) -> Unit)? = null

    /// Registers the callback that receives dashboard control events.
    fun onControlActivated(callback: (ControlId, ActionType) -> Unit) {
        onControlActivated = callback
    }

    /// Reports a dashboard control event.
    fun activate(control: ControlId, action: ActionType) {
        onControlActivated?.invoke(control, action)
    }
}
