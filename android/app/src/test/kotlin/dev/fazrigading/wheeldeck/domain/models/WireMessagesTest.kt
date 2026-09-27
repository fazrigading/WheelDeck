package dev.fazrigading.wheeldeck.domain.models

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Test

/// Pins the wire shape of every schema message: snake_case keys, `type` consts,
/// and optional fields omitted — the desktop's JSON parser contract.
class WireMessagesTest {

    @Test
    fun `state message round-trips with schema keys`() {
        val json = WireJson.encodeToString<WireMessage>(
            State(seq = 1, steering = -0.5, accelerator = 1.0, brake = 0.0, clutch = 0.0),
        )
        assertEquals(
            buildJsonObject {
                put("type", "state")
                put("seq", 1)
                put("steering", -0.5)
                put("accelerator", 1.0)
                put("brake", 0.0)
                put("clutch", 0.0)
            },
            WireJson.parseToJsonElement(json),
        )
        assertEquals(
            State(seq = 1, steering = -0.5, accelerator = 1.0, brake = 0.0, clutch = 0.0),
            WireJson.decodeFromString<WireMessage>(json),
        )
    }

    @Test
    fun `button message round-trips with wire enum values`() {
        val json = WireJson.encodeToString<WireMessage>(
            Button(control = ControlId.TurnSignalLeft.wireValue, action = ActionType.HoldConfirm.wireValue),
        )
        assertEquals(
            buildJsonObject {
                put("type", "button")
                put("control", "turn_signal_left")
                put("action", "hold_confirm")
            },
            WireJson.parseToJsonElement(json),
        )
        assertEquals(
            Button(control = ControlId.TurnSignalLeft.wireValue, action = ActionType.HoldConfirm.wireValue),
            WireJson.decodeFromString<WireMessage>(json),
        )
    }

    @Test
    fun `mapping message round-trips both modes`() {
        for (mode in MappingMode.entries) {
            val json = WireJson.encodeToString<WireMessage>(Mapping(mode.name.lowercase()))
            assertEquals(
                buildJsonObject {
                    put("type", "mapping")
                    put("mode", mode.name.lowercase())
                },
                WireJson.parseToJsonElement(json),
            )
            assertEquals(Mapping(mode.name.lowercase()), WireJson.decodeFromString<WireMessage>(json))
        }
    }

    @Test
    fun `pair request and response round-trip with snake_case keys`() {
        val request = WireJson.encodeToString<WireMessage>(
            PairRequest(deviceId = "phone-1", code = "1234"),
        )
        assertEquals(
            buildJsonObject {
                put("type", "pair_request")
                put("device_id", "phone-1")
                put("code", "1234")
            },
            WireJson.parseToJsonElement(request),
        )

        val response = WireJson.encodeToString<WireMessage>(
            PairResponse(deviceId = "phone-1", accepted = true, sessionToken = "tok"),
        )
        assertEquals(
            buildJsonObject {
                put("type", "pair_response")
                put("device_id", "phone-1")
                put("accepted", true)
                put("session_token", "tok")
            },
            WireJson.parseToJsonElement(response),
        )
        assertEquals(
            PairResponse(deviceId = "phone-1", accepted = true, sessionToken = "tok"),
            WireJson.decodeFromString<WireMessage>(response),
        )
    }

    @Test
    fun `optional fields are omitted when null`() {
        val heartbeat = WireJson.encodeToString<WireMessage>(Heartbeat(sessionToken = null))
        assertEquals("""{"type":"heartbeat"}""", heartbeat)

        val rejected = WireJson.decodeFromString<WireMessage>(
            """{"type":"pair_response","device_id":"phone-1","accepted":false}""",
        )
        assertEquals(PairResponse(deviceId = "phone-1", accepted = false, sessionToken = null), rejected)
    }

    @Test
    fun `unknown inbound fields are ignored for forward compatibility`() {
        val decoded = WireJson.decodeFromString<WireMessage>(
            """{"type":"heartbeat","session_token":"tok","some_future_field":42}""",
        )
        assertEquals(Heartbeat(sessionToken = "tok"), decoded)
    }
}
