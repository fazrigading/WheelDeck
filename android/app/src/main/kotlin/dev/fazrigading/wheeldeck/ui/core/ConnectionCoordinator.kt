package dev.fazrigading.wheeldeck.ui.core

import android.content.Context
import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.PairedDeviceRepository
import dev.fazrigading.wheeldeck.data.repositories.ServerDiscoveryRepository
import dev.fazrigading.wheeldeck.data.repositories.SessionRepository
import dev.fazrigading.wheeldeck.data.services.PairingController
import dev.fazrigading.wheeldeck.data.services.ServerDiscovery
import dev.fazrigading.wheeldeck.data.services.WheelDeckClient
import dev.fazrigading.wheeldeck.domain.models.PairingChallenge
import dev.fazrigading.wheeldeck.domain.models.PairingMethod
import dev.fazrigading.wheeldeck.ui.features.connection.view_models.ConnectionViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/// Wires the network stack: services ([WheelDeckClient], [ServerDiscovery],
/// [PairingController]), repositories, and the [ConnectionViewModel]. Screens
/// bind to `viewModel.uiState` via `collectAsStateWithLifecycle` and call the
/// ViewModel directly.
class ConnectionCoordinator(container: ConnectionContainer) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    val viewModel: ConnectionViewModel = ConnectionViewModel(
        discoveryRepository = ServerDiscoveryRepository(ServerDiscovery(container.appContext)),
        connectionRepository = ConnectionRepository(container.client),
        sessionRepository = SessionRepository(container.pairingController),
        pairedDeviceRepository = container.pairedDeviceRepository,
    )

    init {
        // The client exposes pairing-required as a callback without a
        // challenge payload; bridge it into the ViewModel with the default
        // challenge. Desktop pairing is PIN-entry (QR scan is a future method).
        container.client.onPairingRequired {
            scope.launch {
                viewModel.onPairingRequired(PairingChallenge(PairingMethod.Pin))
            }
        }
        // Bootstrap sweep, matching the Dart app's `..refreshDiscovery()`.
        scope.launch { viewModel.refreshDiscovery() }
    }
}

/// Holds the process-wide singletons the coordinator wires together.
class ConnectionContainer(
    val appContext: Context,
    val client: WheelDeckClient,
    val pairingController: PairingController,
    val pairedDeviceRepository: PairedDeviceRepository,
)
