package dev.fazrigading.wheeldeck.domain.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/// Shared codec for the WheelDeck wire protocol (protocol/schema/*.json).
/// `ignoreUnknownKeys` keeps the phone forward-compatible with desktop additions.
val WireJson: Json = Json {
    ignoreUnknownKeys = true
    classDiscriminator = "type"
}

/// Every frame on the WebSocket, discriminated by the `type` field.
@Serializable
sealed interface WireMessage

/// Continuous steering and pedal state; latest value wins (state_message.json).
@Serializable
@SerialName("state")
data class StateMessage(
    val seq: Long,
    val steering: Double,
    val accelerator: Double,
    val brake: Double,
    val clutch: Double,
) : WireMessage

/// Discrete dashboard control event (button_message.json).
@Serializable
@SerialName("button")
data class ButtonMessage(
    val control: ControlId,
    val action: ActionType,
) : WireMessage

/// Mapping-mode switch sent by the phone (mapping_message.json).
@Serializable
@SerialName("mapping")
data class MappingMessage(
    val mode: MappingMode,
) : WireMessage

@Serializable
enum class MappingMode {
    @SerialName("keyboard") Keyboard,
    @SerialName("gamepad") Gamepad,
}

/// Pairing, heartbeat, and device-selection frames (session_messages.json).
@Serializable
@SerialName("pair_request")
data class PairRequest(
    @SerialName("device_id") val deviceId: String,
    val code: String,
) : WireMessage

@Serializable
@SerialName("pair_response")
data class PairResponse(
    @SerialName("device_id") val deviceId: String,
    val accepted: Boolean,
    @SerialName("session_token") val sessionToken: String? = null,
) : WireMessage

@Serializable
@SerialName("heartbeat")
data class Heartbeat(
    @SerialName("session_token") val sessionToken: String? = null,
) : WireMessage

@Serializable
@SerialName("device_switch")
data class DeviceSwitch(
    @SerialName("device_id") val deviceId: String? = null,
) : WireMessage
