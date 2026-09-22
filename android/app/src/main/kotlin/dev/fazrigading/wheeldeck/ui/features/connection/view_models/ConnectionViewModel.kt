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

    /// Closes the socket and returns to `disconnected`.
    fun disconnect() = connectionRepository.disconnect()

    /// Pauses the session on lifecycle interruption. Keeps the WebSocket open
    /// for fast reconnect — the driving view stops sending input instead.
    fun pause() {
        if (_uiState.value.isPaused) return
        _uiState.update { it.copy(isPaused = true) }
    }

    /// Clears the pause flag so the UI can re-confirm calibration.
    fun resume() {
        _uiState.update { it.copy(isPaused = false) }
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

    companion object
}