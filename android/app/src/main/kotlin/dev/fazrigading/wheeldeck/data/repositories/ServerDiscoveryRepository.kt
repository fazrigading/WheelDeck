package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.ServerDiscovery
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer

/// Single source of truth for discovered servers.
///
/// Wraps the stateless [ServerDiscovery] service, caches the last sweep, and
/// exposes domain models to ViewModels.
class ServerDiscoveryRepository(private val discovery: ServerDiscovery) {
    private var cached: List<DiscoveredServer> = emptyList()

    /// Last discovery results as a snapshot.
    val servers: List<DiscoveredServer>
        get() = cached.toList()

    /// Runs an mDNS sweep and caches the results.
    suspend fun refresh(): List<DiscoveredServer> = discovery.discover().also { cached = it }

    companion object {
        /// Builds a manual target from user-entered host and optional port.
        fun manualTarget(host: String, port: Int? = null): ConnectionTarget =
            ServerDiscovery.manualTarget(host = host, port = port)
    }
}
