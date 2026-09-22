package dev.fazrigading.wheeldeck.domain.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/// How the phone resolves the desktop server.
@Serializable
enum class ConnectionMode {
    @SerialName("autoDiscover") AutoDiscover,
    @SerialName("manual") Manual,
}

/// Default WebSocket port the desktop server listens on.
const val DefaultWheelDeckPort = 8765

/// The endpoint a connection should dial. Discovery produces `autoDiscover`
/// targets with a resolved [ipAddress]; manual entry sets [ipAddress] and
/// [port] directly.
@Serializable
data class ConnectionTarget(
    val mode: ConnectionMode,
    val ipAddress: String? = null,
    val port: Int? = null,
) {
    /// Resolves to a `ws://` URI. Throws when no host is available yet.
    fun resolve(defaultPort: Int = DefaultWheelDeckPort): String {
        val host = ipAddress ?: error("ConnectionTarget has no IP address to resolve.")
        return "ws://$host:${port ?: defaultPort}/"
    }
}
