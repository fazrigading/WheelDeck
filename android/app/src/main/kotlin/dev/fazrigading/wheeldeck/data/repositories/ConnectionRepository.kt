package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.WheelDeckClient
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.State
import kotlinx.coroutines.flow.StateFlow

/// Single source of truth for the WebSocket connection.
///
/// Thin pass-through over the [WheelDeckClient] service so ViewModels never
/// touch transport framing directly.
class ConnectionRepository(private val client: WheelDeckClient) {
    val status: StateFlow<ConnectionStatus> = client.status
    val lastTarget: ConnectionTarget? get() = client.lastTarget

    fun connect(target: ConnectionTarget) = client.connect(target)

    fun disconnect() = client.disconnect()

    /// Sends a `state` frame with the current input values.
    fun sendState(state: State) = client.sendState(
        steering = state.steering,
        accelerator = state.accelerator,
        brake = state.brake,
        clutch = state.clutch,
    )

    /// Sends a `button` frame for a dashboard control event.
    fun sendButtonEvent(control: String, action: String) = client.sendButtonEvent(control, action)

    /// Sends the desired dashboard input mapping (`keyboard` or `gamepad`).
    fun sendMappingMode(mode: String) = client.sendMappingMode(mode)
}
