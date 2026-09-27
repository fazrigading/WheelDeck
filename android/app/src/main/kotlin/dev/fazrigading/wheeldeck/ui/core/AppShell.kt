package dev.fazrigading.wheeldeck.ui.core

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.ui.features.connection.views.ConnectionScreen
import dev.fazrigading.wheeldeck.ui.features.driving.views.DrivingScreen
import dev.fazrigading.wheeldeck.ui.features.onboarding.views.OnboardingScreen
import dev.fazrigading.wheeldeck.ui.features.settings.views.SettingsScreen
import kotlinx.coroutines.launch

/// Where the app shell is: onboarding once, then the connection screen until
/// paired, then driving. Settings is an overlay on driving, not a step in the
/// flow.
///
/// Every step gates the next: onboarding must be complete, and driving needs a
/// live connection, so neither can be reached by skipping the step before it.
@Composable
fun AppShell(coordinator: ConnectionCoordinator, modifier: Modifier = Modifier) {
    var onboardingComplete by remember { mutableStateOf<Boolean?>(null) }
    var showSettings by remember { mutableStateOf(false) }
    val connectionState by coordinator.viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { onboardingComplete = coordinator.onboardingRepository.isComplete() }

    // null = still reading the flag; showing anything before that would flash the
    // onboarding screen at a returning driver.
    val onboarded = onboardingComplete
    if (onboarded == null) return

    Box(modifier = modifier.fillMaxSize()) {
        if (!onboarded) {
            OnboardingScreen(
                viewModel = coordinator.onboardingViewModel,
                onComplete = { onboardingComplete = true },
            )
            return@Box
        }

        if (showSettings) {
            SettingsScreen(
                viewModel = coordinator.settingsViewModel,
                onBack = {
                    showSettings = false
                    // Settings changed what the driving screen reads, so re-read.
                    scope.launch { coordinator.drivingViewModel.init() }
                },
            )
            return@Box
        }

        if (connectionState.status == ConnectionStatus.Connected) {
            DrivingScreen(
                viewModel = coordinator.drivingViewModel,
                pedals = coordinator.pedals,
                dashboardInput = coordinator.dashboardInput,
                onOpenSettings = { showSettings = true },
            )
        } else {
            ConnectionScreen(
                viewModel = coordinator.viewModel,
                onOpenSettings = { showSettings = true },
            )
        }
    }
}
