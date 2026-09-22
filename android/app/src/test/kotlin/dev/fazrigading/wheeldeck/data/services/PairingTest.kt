package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ConnectionMode
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.WireJson
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CopyOnWriteArrayList

/// Port of mobile's pairing_test.dart, driven against MockWebServer the same
/// way as WheelDeckClientTest.
class PairingTest {

    private class MemoryTokenStore : SessionTokenStore {
        var token: String? = null
        var saveCount = 0

        override suspend fun load(): String? = token

        override suspend fun save(token: String) {
            saveCount++
            this.token = token
        }

        override suspend fun clear() {
            token = null
        }
    }

    private lateinit var server: MockWebServer
    private lateinit var store: MemoryTokenStore
    private lateinit var client: WheelDeckClient
    private lateinit var pairing: PairingController
    private val sent = CopyOnWriteArrayList<String>()
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
        store = MemoryTokenStore()
        client = WheelDeckClient(
            deviceId = "phone-1",
            heartbeatIntervalMs = 50L,
            reconnectIntervalMs = 100L,
        )
        pairing = PairingController(store = store, client = client)
    }

    @After
    fun tearDown() {
        client.disconnect()
        server.shutdown()
    }

    private fun framesOfType(type: String) = sent
        .map { WireJson.parseToJsonElement(it).jsonObject }
        .filter { it["type"]!!.jsonPrimitive.content == type }

    private fun await(timeoutMs: Long = 2000L, condition: () -> Boolean) {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (!condition()) {
            if (System.currentTimeMillis() > deadline) throw AssertionError("timed out")
            Thread.sleep(10)
        }
    }

    private fun connect() {
        server.enqueue(MockResponse().withWebSocketUpgrade(serverListener))
        client.connect(
            ConnectionTarget(mode = ConnectionMode.Manual, ipAddress = "127.0.0.1", port = server.port),
        )
        await { client.status.value != ConnectionStatus.Connecting }
    }

    @Test
    fun `restoreSession returns the stored token`() = runTest {
        store.token = "persisted-token"

        assertEquals("persisted-token", pairing.restoreSession())
    }

    @Test
    fun `restoreSession returns null when nothing is stored`() = runTest {
        assertNull(pairing.restoreSession())
    }

    @Test
    fun `submitPairingCode sends a pair_request through the client`() = runTest {
        connect()
        sent.clear()

        pairing.submitPairingCode("123456")
        await { framesOfType("pair_request").isNotEmpty() }

        val message = framesOfType("pair_request").single()
        assertEquals("pair_request", message["type"]!!.jsonPrimitive.content)
        assertEquals("phone-1", message["device_id"]!!.jsonPrimitive.content)
        assertEquals("123456", message["code"]!!.jsonPrimitive.content)
    }

    @Test
    fun `an accepted pair_response persists the session token`() = runTest {
        connect()

        serverSocket!!.send(
            """{"type":"pair_response","device_id":"phone-1","accepted":true,"session_token":"fresh-token"}""",
        )
        await { store.saveCount >= 1 }

        assertEquals("fresh-token", store.load())
        assertEquals(1, store.saveCount)
    }

    @Test
    fun `a rejected pair_response does not persist a token`() = runTest {
        connect()

        serverSocket!!.send(
            """{"type":"pair_response","device_id":"phone-1","accepted":false}""",
        )
        // Give the callbacks a beat to (not) fire.
        Thread.sleep(200)

        assertNull(store.load())
        assertEquals(0, store.saveCount)
    }
}
