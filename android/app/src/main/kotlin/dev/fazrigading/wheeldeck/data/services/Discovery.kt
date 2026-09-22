package dev.fazrigading.wheeldeck.data.services

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import dev.fazrigading.wheeldeck.domain.models.ConnectionMode
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.DefaultWheelDeckPort
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay

/// The DNS-SD service type the desktop advertises under.
///
/// Android's NsdManager wants the type without the `.local` domain but with a
/// trailing dot; the Dart app used `_wheeldeck._tcp.local`. This constant is
/// the single place where the Android format lives.
const val WheelDeckServiceType = "_wheeldeck._tcp."

/// Resolves advertised WheelDeck servers to dialable targets.
fun interface ServerResolver {
    suspend fun resolve(): List<DiscoveredServer>
}

/// Discovers desktop servers via mDNS and exposes manual-IP entry as the
/// fallback for networks that block multicast (public Wi-Fi with client
/// isolation, per the PRD).
class ServerDiscovery(private val resolver: ServerResolver) {
    constructor(context: Context) : this(NsdResolver(context))

    /// Queries the network for advertised WheelDeck servers.
    suspend fun discover(): List<DiscoveredServer> = resolver.resolve()

    companion object {
        /// Builds a manual target from a user-entered host and optional port.
        fun manualTarget(host: String, port: Int? = null) = ConnectionTarget(
            mode = ConnectionMode.Manual,
            ipAddress = host,
            port = port ?: DefaultWheelDeckPort,
        )
    }
}

/// Drives [NsdManager] through discovery and per-instance resolution.
/// ponytail: fixed 3s one-shot sweep window; switch to continuous discovery
/// with onServiceLost updates if stale entries become a real problem.
class NsdResolver(context: Context, private val discoveryWindowMillis: Long = 3_000) : ServerResolver {
    private val nsManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager

    override suspend fun resolve(): List<DiscoveredServer> = coroutineScope {
        val servers = CopyOnWriteArrayList<DiscoveredServer>()
        val started = CompletableDeferred<Unit>()
        val listener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                started.complete(Unit)
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                started.completeExceptionally(
                    IllegalStateException("NSD discovery failed to start: $errorCode"),
                )
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                nsManager.resolveService(
                    serviceInfo,
                    object : NsdManager.ResolveListener {
                        override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {}

                        override fun onServiceResolved(info: NsdServiceInfo) {
                            servers.add(info.toDiscoveredServer())
                        }
                    },
                )
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {}

            override fun onDiscoveryStopped(serviceType: String) {}

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
        }

        nsManager.discoverServices(WheelDeckServiceType, NsdManager.PROTOCOL_DNS_SD, listener)
        try {
            started.await()
            delay(discoveryWindowMillis)
        } finally {
            runCatching { nsManager.stopServiceDiscovery(listener) }
        }
        servers.toList()
    }

    private fun NsdServiceInfo.toDiscoveredServer() = DiscoveredServer(
        host = host?.hostAddress.orEmpty(),
        port = port,
        name = serviceName,
    )
}
