package dev.fazrigading.wheeldeck.data.repositories

import dev.fazrigading.wheeldeck.data.services.ServerDiscovery
import dev.fazrigading.wheeldeck.domain.models.ConnectionMode
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class ServerDiscoveryRepositoryTest {

    @Test
    fun `refresh caches the sweep and exposes a snapshot`() = runTest {
        val first = listOf(DiscoveredServer(host = "192.168.1.10", port = 8765, name = "Desktop"))
        var results = first
        val repository = ServerDiscoveryRepository(ServerDiscovery { results })

        assertEquals(first, repository.refresh())
        assertEquals(first, repository.servers)

        val second = listOf(
            DiscoveredServer(host = "192.168.1.10", port = 8765, name = "Desktop"),
            DiscoveredServer(host = "192.168.1.20", port = 8765, name = "Laptop"),
        )
        results = second
        assertEquals(second, repository.refresh())
        assertEquals(second, repository.servers)
    }

    @Test
    fun `servers snapshot is isolated from later refreshes`() = runTest {
        val first = listOf(DiscoveredServer(host = "192.168.1.10", port = 8765, name = "Desktop"))
        var results = first
        val repository = ServerDiscoveryRepository(ServerDiscovery { results })
        repository.refresh()
        val snapshot = repository.servers

        results = emptyList()
        repository.refresh()

        assertEquals(first, snapshot)
        assertEquals(emptyList<DiscoveredServer>(), repository.servers)
    }

    @Test
    fun `manual target delegates to the service`() {
        val target = ServerDiscoveryRepository.manualTarget(host = "192.168.1.50", port = 9000)

        assertEquals(ConnectionMode.Manual, target.mode)
        assertEquals(9000, target.port)
    }
}
