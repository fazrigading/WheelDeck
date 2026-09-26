package dev.fazrigading.wheeldeck.data.services

import android.util.Log
import dev.fazrigading.wheeldeck.domain.models.Button
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.DefaultWheelDeckPort
import dev.fazrigading.wheeldeck.domain.models.Heartbeat
import dev.fazrigading.wheeldeck.domain.models.Mapping
import dev.fazrigading.wheeldeck.domain.models.PairRequest
import dev.fazrigading.wheeldeck.domain.models.PairResponse
import dev.fazrigading.wheeldeck.domain.models.State
import dev.fazrigading.wheeldeck.domain.models.Unpair
import dev.fazrigading.wheeldeck.domain.models.WireJson
import dev.fazrigading.wheeldeck.domain.models.WireMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import okio.ByteString
import java.util.concurrent.atomic.AtomicLong

class WheelDeckClient(
    private val deviceId: String,
    private val heartbeatIntervalMs: Long = 2000L,
    private val reconnectIntervalMs: Long = 3000L,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Default),
) : WebSocketListener() {
    private val client = OkHttpClient()

    private val _status = MutableStateFlow(ConnectionStatus.Disconnected)
    val status: StateFlow<ConnectionStatus> = _status.asStateFlow()

    private val seq = AtomicLong(0)
    private var webSocket: WebSocket? = null
    private var sessionToken: String? = null

    /// True between [disconnect] and the next [connect]; suppresses the error
    /// log for the socket teardown the user asked for.
    private var userRequestedClose = false

    /// Last connection target, used to reconnect after a lifecycle pause.
    var lastTarget: ConnectionTarget? = null
        private set
    private var heartbeatJob: Job? = null
    private var reconnectJob: Job? = null

    private var onConnectionStatusChanged: ((ConnectionStatus) -> Unit)? = null
    private var onPairingRequired: (() -> Unit)? = null
    private var onPairingAccepted: ((String) -> Unit)? = null
    private var onUnpair: (() -> Unit)? = null

    companion object {
        private const val TAG = "WheelDeckClient"
    }

    fun onConnectionStatusChanged(callback: (ConnectionStatus) -> Unit) {
        onConnectionStatusChanged = callback
    }

    fun onPairingRequired(callback: () -> Unit) {
        onPairingRequired = callback
    }

    fun onPairingAccepted(callback: (String) -> Unit) {
        onPairingAccepted = callback
    }

    fun onUnpair(callback: () -> Unit) {
        onUnpair = callback
    }

    fun setSessionToken(token: String?) {
        sessionToken = token
    }

    fun connect(target: ConnectionTarget) {
        lastTarget = target
        userRequestedClose = false
        cancelReconnectTimer()
        setStatus(ConnectionStatus.Connecting)

        val uri = target.resolve(defaultPort = DefaultWheelDeckPort)
        val request = Request.Builder()
            .url(uri)
            .build()

        webSocket = client.newWebSocket(request, this)
    }

    fun disconnect() {
        lastTarget = null
        userRequestedClose = true
        cancelReconnectTimer()
        cancelHeartbeatTimer()

        // Graceful close would wait on the close handshake and hang
        // MockWebServer-based tests; cancel() is proven and the unpair frame
        // is flushed with a short delay by the caller that needs it.
        webSocket?.cancel()
        webSocket = null
        setStatus(ConnectionStatus.Disconnected)
    }

    fun sendState(
        steering: Double,
        accelerator: Double,
        brake: Double,
        clutch: Double,
        cameraX: Double = 0.0,
        cameraY: Double = 0.0,
    ) {
        val message = State(
            seq = seq.incrementAndGet(),
            steering = steering,
            accelerator = accelerator,
            brake = brake,
            clutch = clutch,
            cameraX = cameraX,
            cameraY = cameraY,
        )
        sendMessage(message)
    }

    fun sendButtonEvent(control: String, action: String) {
        val message = Button(
            control = control,
            action = action,
        )
        sendMessage(message)
    }

    fun submitPairingCode(code: String) {
        val message = PairRequest(
            deviceId = deviceId,
            code = code,
        )
        sendMessage(message)
    }

    fun sendMappingMode(mode: String) {
        val message = Mapping(
            mode = mode,
        )
        sendMessage(message)
    }

    /// Tells the desktop to revoke this device's pairing. Send while the socket
    /// is still open, before disconnecting.
    fun sendUnpair() {
        sendMessage(Unpair)
    }

    override fun onOpen(webSocket: WebSocket, response: Response) {
        Log.d(TAG, "WebSocket opened")

        if (sessionToken == null) {
            setStatus(ConnectionStatus.PairingRequired)
            onPairingRequired?.invoke()
        } else {
            setStatus(ConnectionStatus.Connected)
        }

        scheduleHeartbeat()
        sendHeartbeat()
    }

    override fun onMessage(webSocket: WebSocket, text: String) {
        Log.d(TAG, "Received message: $text")
        handleTextMessage(text)
    }

    override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
        Log.d(TAG, "Received binary message: ${bytes.hex()}")
    }

    override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        Log.d(TAG, "WebSocket closed: $code $reason")
        webSocketCleanup()
        handleConnectionClosed()
    }

    override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        Log.d(TAG, "WebSocket closing: $code $reason")
        webSocket.close(code, reason)
    }

    override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        when {
            userRequestedClose -> Log.d(TAG, "WebSocket closed by user: ${t.message}")
            // Already in the reconnect loop: a failed retry (e.g. ENETUNREACH
            // while Wi-Fi is still down) is expected, not an error.
            _status.value == ConnectionStatus.Reconnecting ->
                Log.d(TAG, "Reconnect attempt failed: ${t.message}")
            else -> Log.e(TAG, "WebSocket failure", t)
        }
        webSocketCleanup()

        // Connection errors like connection refused are reconnectable
        val isReconnectable = response == null
        if (isReconnectable) {
            handleConnectionClosed()
        } else {
            setStatus(ConnectionStatus.Disconnected)
        }
    }

    private fun handleTextMessage(text: String) {
        try {
            val message = WireJson.decodeFromString<WireMessage>(text)

            when (message) {
                is PairResponse -> {
                    if (message.accepted) {
                        message.sessionToken?.let { token ->
                            sessionToken = token
                            onPairingAccepted?.invoke(token)
                        }
                        setStatus(ConnectionStatus.Connected)
                    } else {
                        setStatus(ConnectionStatus.PairingRequired)
                        onPairingRequired?.invoke()
                    }
                }
                is Unpair -> {
                    Log.d(TAG, "Desktop revoked this pairing")
                    onUnpair?.invoke()
                }
                else -> {
                    // Other message types are handled by the UI layer
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse message: $text", e)
        }
    }

    private fun sendMessage(message: WireMessage) {
        val json = WireJson.encodeToString(message)
        webSocket?.send(json)
    }

    private fun scheduleHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope.launch {
            while (isActive) {
                delay(heartbeatIntervalMs)
                sendHeartbeat()
            }
        }
    }

    private fun cancelHeartbeatTimer() {
        heartbeatJob?.cancel()
        heartbeatJob = null
    }

    private fun sendHeartbeat() {
        if (webSocket == null) return

        val message = Heartbeat(
            sessionToken = sessionToken,
        )
        sendMessage(message)
    }

    private fun webSocketCleanup() {
        webSocket?.let {
            try {
                it.cancel()
            } catch (_: CancellationException) {
            } catch (_: Exception) {
            }
        }
        webSocket = null
    }

    private fun handleConnectionClosed() {
        cancelHeartbeatTimer()

        val target = lastTarget
        if (target == null) {
            setStatus(ConnectionStatus.Disconnected)
            return
        }

        setStatus(ConnectionStatus.Reconnecting)
        scheduleReconnect(target)
    }

    private fun scheduleReconnect(target: ConnectionTarget) {
        reconnectJob?.cancel()
        reconnectJob = scope.launch {
            delay(reconnectIntervalMs)
            connect(target)
        }
    }

    private fun cancelReconnectTimer() {
        reconnectJob?.cancel()
        reconnectJob = null
    }

    private fun setStatus(next: ConnectionStatus) {
        if (_status.value == next) return
        _status.value = next
        onConnectionStatusChanged?.invoke(next)
    }
}
