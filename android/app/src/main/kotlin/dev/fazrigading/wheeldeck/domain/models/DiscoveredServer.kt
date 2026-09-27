package dev.fazrigading.wheeldeck.domain.models

import kotlinx.serialization.Serializable

/// A desktop server resolved through mDNS or entered manually.
@Serializable
data class DiscoveredServer(
    /// IP address the WebSocket listener is reachable at.
    val host: String,

    /// WebSocket port the desktop server listens on.
    val port: Int,

    /// Human-readable service instance name, for the selection UI.
    val name: String,
) {
    fun toConnectionTarget() = ConnectionTarget(
        mode = ConnectionMode.AutoDiscover,
        ipAddress = host,
        port = port,
    )
}
