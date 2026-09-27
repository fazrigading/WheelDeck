package dev.fazrigading.wheeldeck.ui.features.connection.view_models

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.PairedDeviceRepository
import dev.fazrigading.wheeldeck.data.repositories.ServerDiscoveryRepository
import dev.fazrigading.wheeldeck.data.repositories.SessionRepository
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.DefaultWheelDeckPort
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import dev.fazrigading.wheeldeck.domain.models.PairingChallenge
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/// Presentation state snapshot for the connection/pairing flow.
data class ConnectionUiState(
    val status: ConnectionStatus = ConnectionStatus.Disconnected,
    val servers: List<DiscoveredServer> = emptyList(),
    val pairingChallenge: PairingChallenge? = null,
    val pairingError: Boolean = false,
    val isPaused: Boolean = false,
    /// True after a lifecycle resume until the user re-confirms the steering
    /// center. Always set, regardless of detected drift (CONTEXT.md:
    /// Calibration reconfirm). The driving view gates input on it; it also
    /// re-centers the sensor, which only the driving screen can reach.
    val awaitingCalibration: Boolean = false,
    val pairedIds: Set<String> = emptySet(),
) {
    /// Previously paired (host:port seen in successful connection).
    val pairedServers: List<DiscoveredServer>
        get() = servers.filter { "${it.host}:${it.port}" in pairedIds }

    /// Discovered but not yet paired.
    val unpairedServers: List<DiscoveredServer>
        get() = servers.filter { "${it.host}:${it.port}" !in pairedIds }
}

/// Presentation state for the connection/pairing flow.
///
/// Owns no transport: [ServerDiscoveryRepository], [ConnectionRepository], and
/// [SessionRepository] are injected via the constructor. The View renders via
/// `collectAsStateWithLifecycle`.
class ConnectionViewModel(
    private val discoveryRepository: ServerDiscoveryRepository,
    private val connectionRepository: ConnectionRepository,
    private val sessionRepository: SessionRepository,
    private val pairedDeviceRepository: PairedDeviceRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ConnectionUiState(status = connectionRepository.status.value))
    val uiState: StateFlow<ConnectionUiState> = _uiState.asStateFlow()

    /// Set once the user has sent a code this pairing round; when the desktop
    /// re-challenges afterwards, the prompt shows the rejected-code error.
    private var pairingSubmitted = false

    init {
        viewModelScope.launch {
            connectionRepository.status.collect { status ->
                if (status == _uiState.value.status) return@collect
                _uiState.update { it.copy(status = status) }
                if (status == ConnectionStatus.Connected) {
                    pairingSubmitted = false
                    _uiState.update {
                        it.copy(pairingChallenge = null, pairingError = false)
                    }
                    rememberPaired(connectionRepository.lastTarget)
                } else if (status != ConnectionStatus.PairingRequired) {
                    // Disconnect/reconnect ends any open pairing round; without
                    // this the PIN modal lingers over a "Disconnected" card.
                    pairingSubmitted = false
                    _uiState.update {
                        it.copy(pairingChallenge = null, pairingError = false)
                    }
                }
            }
        }
    }

    /// Runs an mDNS discovery sweep and updates [servers].
    suspend fun refreshDiscovery() {
        discoveryRepository.refresh()
        _uiState.update { it.copy(servers = discoveryRepository.servers) }
    }

    /// Fire-and-forget sweep for UI event handlers.
    fun refreshDiscoveryAsync() {
        viewModelScope.launch { refreshDiscovery() }
    }

    /// Builds a manual target from user-entered host and optional port.
    fun connectManual(host: String, port: Int? = null) = connect(
        ServerDiscoveryRepository.manualTarget(host = host, port = port),
    )

    /// Connects to [target], restoring any persisted session token first.
    fun connect(target: ConnectionTarget) {
        viewModelScope.launch {
            sessionRepository.restoreSession()
            connectionRepository.connect(target)
        }
    }

    /// Closes the socket and returns to `disconnected`. Leaving driving drops
    /// the calibration prompt with it.
    fun disconnect() {
        _uiState.update { it.copy(awaitingCalibration = false) }
        connectionRepository.disconnect()
    }

    /// Pauses the session on lifecycle interruption. Keeps the WebSocket open
    /// for fast reconnect — the driving view stops sending input instead.
    fun pause() {
        if (_uiState.value.isPaused) return
        _uiState.update { it.copy(isPaused = true) }
    }

    /// Clears the pause flag so the UI can re-confirm calibration, and arms
    /// the reconfirm prompt. Every resume prompts, even one that follows a
    /// confirmation moments earlier.
    fun resume() {
        _uiState.update { it.copy(isPaused = false, awaitingCalibration = true) }
    }

    /// The user accepted the current orientation as straight ahead. The
    /// driving screen also re-centers the sensor when it handles this.
    fun confirmCalibration() {
        _uiState.update { it.copy(awaitingCalibration = false) }
    }

    /// Sends the pairing code entered by the user.
    fun submitPairingCode(code: String) {
        pairingSubmitted = true
        sessionRepository.submitPairingCode(code)
        _uiState.update { it.copy(pairingError = false) }
    }

    fun onPairingRequired(challenge: PairingChallenge) {
        _uiState.update {
            it.copy(pairingChallenge = challenge, pairingError = pairingSubmitted)
        }
    }

    private suspend fun rememberPaired(target: ConnectionTarget?) {
        val host = target?.ipAddress
        val port = target?.port ?: DefaultWheelDeckPort
        if (host.isNullOrEmpty()) return
        try {
            pairedDeviceRepository.addPaired(host, port)
            _uiState.update { it.copy(pairedIds = pairedDeviceRepository.load()) }
        } catch (_: Exception) {
        }
    }

    /// Removes a paired device and forgets its session token so the next
    /// connect re-pairs from scratch. When it is the currently connected
    /// receiver, revokes the pairing on the desktop first and disconnects.
    fun forgetPaired(server: DiscoveredServer) {
        viewModelScope.launch {
            val target = connectionRepository.lastTarget
            val isConnectedHere = target?.ipAddress == server.host &&
                (target.port ?: DefaultWheelDeckPort) == server.port
            if (isConnectedHere) {
                connectionRepository.sendUnpair()
                // Let OkHttp flush the frame before the socket is cancelled.
                delay(100)
            }
            disconnect()
            try {
                sessionRepository.forgetSession()
                pairedDeviceRepository.removePaired(server.host, server.port)
                _uiState.update { it.copy(pairedIds = pairedDeviceRepository.load()) }
            } catch (_: Exception) {
            }
        }
    }

    /// The desktop revoked this pairing (removed from its device list). Drop
    /// the token and paired entry, stop the reconnect loop, and stay on the
    /// connection screen with the stale receiver now unpaired.
    fun onRevokedByDesktop() {
        viewModelScope.launch {
            val target = connectionRepository.lastTarget
            disconnect()
            try {
                sessionRepository.forgetSession()
                val host = target?.ipAddress
                val port = target?.port ?: DefaultWheelDeckPort
                if (!host.isNullOrEmpty()) {
                    pairedDeviceRepository.removePaired(host, port)
                }
                _uiState.update { it.copy(pairedIds = pairedDeviceRepository.load()) }
            } catch (_: Exception) {
            }
        }
    }

    companion object
}