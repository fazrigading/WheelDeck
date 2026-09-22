package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ConnectionMode
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.WireJson
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean

/// Ports of mobile's wheeldeck_client_test.dart and heartbeat_test.dart,
/// driven against MockWebServer. OkHttp runs on real threads, so the client
/// is built with tiny intervals and awaits poll instead of virtual time.
class WheelDeckClientTest {

    private lateinit var server: MockWebServer
    private var client: WheelDeckClient? = null
    private val sent = CopyOnWriteArrayList<String>()
    private val statuses = CopyOnWriteArrayList<ConnectionStatus>()
    private val acceptedTokens = CopyOnWriteArrayList<String>()
    private val pairingChallenged = AtomicBoolean(false)
    private var serverSocket: WebSocket? = null

    private val serverListener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: okhttp3.Response) {
            serverSocket = webSocket
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            sent.add(text)
        }
    }

    @Before
    fun setUp() {
        server = MockWebServer()
        server.start()
    }

    @After
    fun tearDown() {
        client?.disconnect()
        server.shutdown()
    }

    private fun buildClient(): WheelDeckClient =
        WheelDeckClient(
            deviceId = "phone-1",
            heartbeatIntervalMs = 50L,
            reconnectIntervalMs = 100L,
        ).also {
            client = it
            it.onConnectionStatusChanged { statuses.add(it) }
            it.onPairingAccepted { acceptedTokens.add(it) }
            it.onPairingRequired { pairingChallenged.set(true) }
        }

    private fun target() = ConnectionTarget(
        mode = ConnectionMode.Manual,
        ipAddress = "127.0.0.1",
        port = server.port,
    )

    private fun await(timeoutMs: Long = 2000L, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (!condition()) {
            if (System.currentTimeMillis() > deadline) throw AssertionError("timed out")
            Thread.sleep(10)
        }
    }

    private fun frames() = sent.map { WireJson.parseToJsonElement(it).jsonObject }

    private fun framesOfType(type: String) = frames().filter {
        it["type"]!!.jsonPrimitive.content == type
    }

    private fun connectWithToken(token: String? = "saved-token"): WheelDeckClient {
        server.enqueue(MockResponse().withWebSocketUpgrade(serverListener))
        val c = buildClient()
        token?.let(c::setSessionToken)
        c.connect(target())
        await {
            statuses.lastOrNull() == ConnectionStatus.Connected ||
                statuses.lastOrNull() == ConnectionStatus.PairingRequired
        }
        return c
    }

    @Test
    fun `connect resolves the target and reports connected`() {
        connectWithToken()

        assertEquals(
            listOf(ConnectionStatus.Connecting, ConnectionStatus.Connected),
            statuses.toList(),
        )
    }

    @Test
    fun `connect without a session token requests pairing`() {
        connectWithToken(token = null)

        assertEquals(
            listOf(ConnectionStatus.Connecting, ConnectionStatus.PairingRequired),
            statuses.toList(),
        )
        assertTrue(pairingChallenged.get())
    }

    @Test
    fun `manual target without an IP address throws on connect`() {
        assertThrows(IllegalStateException::class.java) {
            ConnectionTarget(mode = ConnectionMode.Manual).resolve()
        }
    }

    @Test
    fun `sendState frames a state message with a monotonic sequence`() {
        connectWithToken()
        sent.clear()

        client!!.sendState(steering = 0.42, accelerator = 0.85, brake = 0.0, clutch = 1.0)
        client!!.sendState(steering = -0.1, accelerator = 0.2, brake = 0.3, clutch = 0.4)
        await { frames().size >= 2 }

        val first = frames()[0]
        assertEquals("state", first["type"]!!.jsonPrimitive.content)
        assertEquals("1", first["seq"]!!.jsonPrimitive.content)
        assertEquals("0.42", first["steering"]!!.jsonPrimitive.content)
        assertEquals("0.85", first["accelerator"]!!.jsonPrimitive.content)
        assertEquals("0.0", first["brake"]!!.jsonPrimitive.content)
        assertEquals("1.0", first["clutch"]!!.jsonPrimitive.content)

        val second = frames()[1]
        assertEquals("2", second["seq"]!!.jsonPrimitive.content)
    }

    @Test
    fun `sendButtonEvent frames a button message using wire values`() {
        connectWithToken()
        sent.clear()

        client!!.sendButtonEvent(control = "turn_signal_left", action = "toggle")
        await { framesOfType("button").isNotEmpty() }

        val message = framesOfType("button").single()
        assertEquals("button", message["type"]!!.jsonPrimitive.content)
        assertEquals("turn_signal_left", message["control"]!!.jsonPrimitive.content)
        assertEquals("toggle", message["action"]!!.jsonPrimitive.content)
    }

    @Test
    fun `submitPairingCode frames a pair_request with the device id`() {
        connectWithToken()
        sent.clear()

        client!!.submitPairingCode("123456")
        await { framesOfType("pair_request").isNotEmpty() }

        val message = framesOfType("pair_request").single()
        assertEquals("pair_request", message["type"]!!.jsonPrimitive.content)
        assertEquals("phone-1", message["device_id"]!!.jsonPrimitive.content)
        assertEquals("123456", message["code"]!!.jsonPrimitive.content)
    }

    @Test
    fun `an accepted pair_response stays connected`() {
        val c = connectWithToken(token = null)
        sent.clear()

        serverSocket!!.send(
            """{"type":"pair_response","device_id":"phone-1","accepted":true,"session_token":"tok"}""",
        )
        await { acceptedTokens.isNotEmpty() }

        assertEquals("tok", acceptedTokens.single())
        assertEquals(ConnectionStatus.Connected, statuses.last())

        c.setSessionToken(null) // Keep tearDown clean of the accepted token.
    }

    @Test
    fun `a rejected pair_response requests pairing`() {
        connectWithToken(token = null)
        sent.clear()
        pairingChallenged.set(false)

        serverSocket!!.send(
            """{"type":"pair_response","device_id":"phone-1","accepted":false}""",
        )
        await { pairingChallenged.get() }

        assertEquals(ConnectionStatus.PairingRequired, statuses.last())
        assertTrue(pairingChallenged.get())
    }

    @Test
    fun `disconnect closes the socket and reports disconnected`() {
        connectWithToken()

        client!!.disconnect()

        assertEquals(ConnectionStatus.Disconnected, statuses.last())
    }

    @Test
    fun `a remote close reports reconnecting`() {
        connectWithToken()

        serverSocket!!.close(1000, "bye")
        await { statuses.lastOrNull() == ConnectionStatus.Reconnecting }

        assertEquals(ConnectionStatus.Reconnecting, statuses.last())
    }

    @Test
    fun `sends a heartbeat with the session token on the interval`() {
        connectWithToken(token = "tok-123")

        await {
            frames().any {
                it["type"]!!.jsonPrimitive.content == "heartbeat" &&
                    it["session_token"]?.jsonPrimitive?.content == "tok-123"
            }
        }
    }

    @Test
    fun `omits the session token when none is set`() {
        connectWithToken(token = null)

        await { frames().any { it["type"]!!.jsonPrimitive.content == "heartbeat" } }

        assertTrue(frames().any { it["type"]!!.jsonPrimitive.content == "heartbeat" && !it.containsKey("session_token") })
    }

    @Test
    fun `reconnects after the fixed interval when the socket closes`() {
        connectWithToken()
        server.enqueue(MockResponse().withWebSocketUpgrade(serverListener))

        serverSocket!!.close(1000, "bye")

        await {
            statuses.count { it == ConnectionStatus.Connected } >= 2 &&
                statuses.contains(ConnectionStatus.Reconnecting)
        }
        assertEquals(ConnectionStatus.Connected, statuses.last())
    }
}
