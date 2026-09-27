package dev.fazrigading.wheeldeck.ui.core

import android.content.Context
import dev.fazrigading.wheeldeck.data.repositories.ConnectionRepository
import dev.fazrigading.wheeldeck.data.repositories.OnboardingRepository
import dev.fazrigading.wheeldeck.data.repositories.PairedDeviceRepository
import dev.fazrigading.wheeldeck.data.repositories.ServerDiscoveryRepository
import dev.fazrigading.wheeldeck.data.repositories.SessionRepository
import dev.fazrigading.wheeldeck.data.repositories.SettingsRepository
import dev.fazrigading.wheeldeck.data.services.DashboardInput
import dev.fazrigading.wheeldeck.data.services.DataStoreSettingsStore
import dev.fazrigading.wheeldeck.data.services.GyroscopeService
import dev.fazrigading.wheeldeck.data.services.PairingController
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.data.services.PermissionPrompts
import dev.fazrigading.wheeldeck.data.services.ServerDiscovery
import dev.fazrigading.wheeldeck.data.services.SteeringSensor
import dev.fazrigading.wheeldeck.data.services.WheelDeckClient
import dev.fazrigading.wheeldeck.data.services.gyroscopeEvents
import dev.fazrigading.wheeldeck.domain.models.PairingChallenge
import dev.fazrigading.wheeldeck.domain.models.PairingMethod
import dev.fazrigading.wheeldeck.ui.features.connection.view_models.ConnectionViewModel
import dev.fazrigading.wheeldeck.ui.features.driving.view_models.DrivingViewModel
import dev.fazrigading.wheeldeck.ui.features.onboarding.view_models.OnboardingViewModel
import dev.fazrigading.wheeldeck.ui.features.settings.view_models.SettingsViewModel
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

    val connectionRepository = ConnectionRepository(container.client)

    /// One store behind every settings-backed repository, so they read and write
    /// the same DataStore instance.
    private val settingsStore = DataStoreSettingsStore(container.appContext)

    val settingsRepository = SettingsRepository(settingsStore)

    val onboardingRepository = OnboardingRepository(settingsStore)

    private val gyro = GyroscopeService(gyroscopeEvents(container.appContext))

    val dashboardInput = DashboardInput()

    val pedals = PedalInput()

    val viewModel: ConnectionViewModel = ConnectionViewModel(
        discoveryRepository = ServerDiscoveryRepository(ServerDiscovery(container.appContext)),
        connectionRepository = connectionRepository,
        sessionRepository = SessionRepository(container.pairingController),
        pairedDeviceRepository = container.pairedDeviceRepository,
    )

    /// The driving and settings view models, built once so their state survives
    /// navigating between screens.
    val drivingViewModel: DrivingViewModel by lazy {
        DrivingViewModel(
            connectionRepository = connectionRepository,
            settingsRepository = settingsRepository,
            sensor = SteeringSensor(gyro.rawAngles),
            pedals = pedals,
            dashboardInput = dashboardInput,
        )
    }

    val settingsViewModel: SettingsViewModel by lazy {
        SettingsViewModel(settingsRepository, connectionRepository)
    }

    val onboardingViewModel: OnboardingViewModel by lazy {
        OnboardingViewModel(PermissionPrompts(), onboardingRepository)
    }

    init {
        // The client exposes pairing-required as a callback without a
        // challenge payload; bridge it into the ViewModel with the default
        // challenge. Desktop pairing is PIN-entry (QR scan is a future method).
        container.client.onPairingRequired {
            scope.launch {
                viewModel.onPairingRequired(PairingChallenge(PairingMethod.Pin))
            }
        }
        // Desktop revoked this device: drop the token and the paired entry so
        // the next connect re-pairs, and stay on the connection screen.
        container.client.onUnpair {
            scope.launch { viewModel.onRevokedByDesktop() }
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
