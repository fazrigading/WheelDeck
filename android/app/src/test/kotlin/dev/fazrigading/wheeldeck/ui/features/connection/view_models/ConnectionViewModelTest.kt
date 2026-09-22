package dev.fazrigading.wheeldeck.ui.features.connection.view_models

import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.PairedDeviceRepository
import dev.fazrigading.wheeldeck.data.repositories.ServerDiscoveryRepository
import dev.fazrigading.wheeldeck.data.repositories.SessionRepository
import dev.fazrigading.wheeldeck.data.services.PairingController
import dev.fazrigading.wheeldeck.data.services.ServerDiscovery
import dev.fazrigading.wheeldeck.data.services.ServerResolver
import dev.fazrigading.wheeldeck.data.services.SessionTokenStore
import dev.fazrigading.wheeldeck.data.services.WheelDeckClient
import dev.fazrigading.wheeldeck.domain.models.ConnectionMode
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.ConnectionTarget
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import dev.fazrigading.wheeldeck.domain.models.PairingChallenge
import dev.fazrigading.wheeldeck.domain.models.PairingMethod
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ConnectionViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private class FakeResolver(private val servers: List<DiscoveredServer> = emptyList()) : ServerResolver {
        override suspend fun resolve(): List<DiscoveredServer> = servers
    }

    private class FakeTokenStore : SessionTokenStore {
        var saved: String? = null
        override suspend fun load(): String? = null
        override suspend fun save(token: String) {
            saved = token
        }
        override suspend fun clear() {
            saved = null
        }
    }

    private class FakePairedStore : dev.fazrigading.wheeldeck.data.repositories.PairedDeviceStore {
        val paired = mutableSetOf<String>()
        override suspend fun load(): Set<String> = paired
        override suspend fun addPaired(host: String, port: Int) {
            paired.add("$host:$port")
        }
        override suspend fun removePaired(host: String, port: Int) {
            paired.remove("$host:$port")
        }
    }

    private class Fixture(servers: List<DiscoveredServer> = emptyList()) {
        val dispatcher = StandardTestDispatcher()
        val scope = CoroutineScope(dispatcher)
        val client = WheelDeckClient(deviceId = "test-device", scope = scope)
        val tokenStore = FakeTokenStore()
        val pairedStore = FakePairedStore()
        val vm = ConnectionViewModel(
            discoveryRepository = ServerDiscoveryRepository(ServerDiscovery(FakeResolver(servers))),
            connectionRepository = ConnectionRepository(client),
            sessionRepository = SessionRepository(PairingController(tokenStore, client, scope)),
            pairedDeviceRepository = PairedDeviceRepository(pairedStore),
        )
    }

    @Test
    fun `initial status comes from client`() = runTest(dispatcher) {
        val f = Fixture()
        assertEquals(ConnectionStatus.Disconnected, f.vm.uiState.value.status)
    }

    @Test
    fun `connect transitions status through Connecting`() = runTest(dispatcher) {
        val f = Fixture()
        f.vm.connect(ConnectionTarget(mode = ConnectionMode.Manual, ipAddress = "127.0.0.1", port = 1))
        advanceUntilIdle()
        assertEquals(ConnectionStatus.Connecting, f.vm.uiState.value.status)
    }

    @Test
    fun `refreshDiscovery updates servers`() = runTest(dispatcher) {
        val f = Fixture(listOf(DiscoveredServer(host = "192.168.1.10", port = 8765, name = "desktop")))

        f.vm.refreshDiscovery()
        advanceUntilIdle()

        assertEquals(1, f.vm.uiState.value.servers.size)
        assertTrue(f.vm.uiState.value.unpairedServers.isNotEmpty())
        assertTrue(f.vm.uiState.value.pairedServers.isEmpty())
    }

    @Test
    fun `onPairingRequired sets challenge`() = runTest(dispatcher) {
        val f = Fixture()
        assertNull(f.vm.uiState.value.pairingChallenge)

        f.vm.onPairingRequired(PairingChallenge(PairingMethod.Pin))
        assertEquals(PairingMethod.Pin, f.vm.uiState.value.pairingChallenge?.method)
    }

    @Test
    fun `submitPairingCode clears pairingError`() = runTest(dispatcher) {
        val f = Fixture()
        f.vm.onPairingRequired(PairingChallenge(PairingMethod.Pin))

        f.vm.submitPairingCode("1234")
        advanceUntilIdle()

        assertFalse(f.vm.uiState.value.pairingError)
    }

    @Test
    fun `pause and resume toggle isPaused`() = runTest(dispatcher) {
        val f = Fixture()
        assertFalse(f.vm.uiState.value.isPaused)

        f.vm.pause()
        assertTrue(f.vm.uiState.value.isPaused)

        f.vm.resume()
        assertFalse(f.vm.uiState.value.isPaused)
    }

    @Test
    fun `disconnect returns to Disconnected`() = runTest(dispatcher) {
        val f = Fixture()
        f.vm.disconnect()
        advanceUntilIdle()
        assertEquals(ConnectionStatus.Disconnected, f.vm.uiState.value.status)
    }
}
