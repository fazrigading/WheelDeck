package dev.fazrigading.wheeldeck

import android.app.Application
import dev.fazrigading.wheeldeck.ui.core.ConnectionContainer
import dev.fazrigading.wheeldeck.ui.core.ConnectionCoordinator

/// Holds the process-wide [AppContainer] and [ConnectionCoordinator].
class WheelDeckApplication : Application() {
    val container: AppContainer by lazy { AppContainer(this) }
    val coordinator: ConnectionCoordinator by lazy {
        ConnectionCoordinator(
            ConnectionContainer(
                appContext = container.appContext,
                client = container.wheelDeckClient,
                pairingController = container.pairingController,
                pairedDeviceRepository = container.pairedDeviceRepository,
            ),
        )
    }
}
