package dev.fazrigading.wheeldeck.data.services

import dev.fazrigading.wheeldeck.domain.models.ConnectionMode
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.DefaultWheelDeckPort
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ServerDiscoveryTest {

    @Test
    fun `discover passes resolver results through`() = runTest {
        val found = listOf(
            DiscoveredServer(host = "192.168.1.10", port = 8765, name = "Desktop"),
            DiscoveredServer(host = "192.168.1.20", port = 8765, name = "Laptop"),
        )
        val discovery = ServerDiscovery { found }

        assertEquals(found, discovery.discover())
    }

    @Test
    fun `manual target defaults to the WheelDeck port`() {
        val target = ServerDiscovery.manualTarget(host = "192.168.1.50")

        assertEquals(ConnectionMode.Manual, target.mode)
        assertEquals("192.168.1.50", target.ipAddress)
        assertEquals(DefaultWheelDeckPort, target.port)
    }

    @Test
    fun `manual target keeps an explicit port`() {
        val target = ServerDiscovery.manualTarget(host = "desktop.local", port = 9000)

        assertEquals(9000, target.port)
    }

    @Test
    fun `discovered server converts to an autoDiscover target`() {
        val server = DiscoveredServer(host = "192.168.1.10", port = 8765, name = "Desktop")

        val target = server.toConnectionTarget()

        assertEquals(ConnectionMode.AutoDiscover, target.mode)
        assertEquals("192.168.1.10", target.ipAddress)
        assertEquals(8765, target.port)
    }

    @Test
    fun `target resolves to a ws URI with default port`() {
        val target = ServerDiscovery.manualTarget(host = "192.168.1.50")

        assertEquals("ws://192.168.1.50:8765/", target.resolve())
    }

    @Test
    fun `target resolve throws without an IP address`() {
        val target = ConnectionTarget(mode = ConnectionMode.AutoDiscover)

        assertThrows(IllegalStateException::class.java) { target.resolve() }
    }
}
