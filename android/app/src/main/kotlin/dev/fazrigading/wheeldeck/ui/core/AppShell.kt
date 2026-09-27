package dev.fazrigading.wheeldeck.ui.core

import androidx.activity.compose.BackHandler
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
import dev.fazrigading.wheeldeck.ui.features.about.views.AboutScreen
import dev.fazrigading.wheeldeck.ui.features.connection.views.ConnectionScreen
import dev.fazrigading.wheeldeck.ui.features.donate.views.DonateScreen
import dev.fazrigading.wheeldeck.ui.features.driving.views.DrivingScreen
import dev.fazrigading.wheeldeck.ui.features.menu.views.MenuScreen
import dev.fazrigading.wheeldeck.ui.features.onboarding.views.OnboardingScreen
import dev.fazrigading.wheeldeck.ui.features.settings.views.SettingsScreen
import kotlinx.coroutines.launch

/// The pages the shell can show.
enum class AppPage {
    Onboarding,
    Menu,
    Connect,
    Settings,
    About,
    Donate,
    Driving,
}

/// Which page owns the window, given where the driver is in the flow.
///
/// Pure, and the only decision the composable makes — so the rules that driving
/// wins over any hub page, and that onboarding wins over everything, are
/// testable without a device. A `paused` session still counts as live: a
/// backgrounded session is a session, and bouncing the driver to the menu there
/// would strand them mid-drive. That mirrors `main.dart`'s
/// `status == connected || isPaused`.
///
/// A stale [AppPage.Driving] request — left over from a session that has since
/// ended — resolves to [AppPage.Menu] rather than showing a screen with no way in.
fun resolvePage(onboarded: Boolean, connected: Boolean, paused: Boolean, requested: AppPage): AppPage = when {
    !onboarded -> AppPage.Onboarding
    connected || paused -> AppPage.Driving
    requested == AppPage.Driving -> AppPage.Menu
    else -> requested
}

/// Routes the app: onboarding once, then the menu hub with the pages it opens, or
/// the driving screen while a session is live.
///
/// Settings is reachable twice — from the hub, and from a corner control on the
/// driving screen — because a driver mid-session should not have to disconnect to
/// change a binding. Mid-session it overlays the still-mounted dashboard, so Back
/// is instant and nothing re-initialises.
@Composable
fun AppShell(coordinator: ConnectionCoordinator, modifier: Modifier = Modifier) {
    // null = still reading the flag; showing anything before that would flash the
    // onboarding screen at a returning driver.
    var onboarded by remember { mutableStateOf<Boolean?>(null) }
    var requested by remember { mutableStateOf(AppPage.Menu) }
    val connectionState by coordinator.viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { onboarded = coordinator.onboardingRepository.isComplete() }

    fun openSettings() {
        requested = AppPage.Settings
    }

    fun closeSettings() {
        requested = AppPage.Menu
        // Settings changed what the driving screen reads, so re-read before the
        // next session.
        scope.launch { coordinator.drivingViewModel.init() }
    }

    val page = resolvePage(
        onboarded = onboarded == true,
        connected = connectionState.status == ConnectionStatus.Connected,
        paused = connectionState.isPaused,
        requested = requested,
    )

    Box(modifier = modifier.fillMaxSize()) {
        when (page) {
            AppPage.Onboarding -> OnboardingScreen(
                viewModel = coordinator.onboardingViewModel,
                onComplete = { onboarded = true },
            )

            AppPage.Driving -> {
                DrivingScreen(
                    viewModel = coordinator.drivingViewModel,
                    pedals = coordinator.pedals,
                    dashboardInput = coordinator.dashboardInput,
                    onOpenSettings = ::openSettings,
                )
                if (requested == AppPage.Settings) {
                    SettingsScreen(
                        viewModel = coordinator.settingsViewModel,
                        onBack = ::closeSettings,
                    )
                }
            }

            AppPage.Menu -> MenuScreen(
                onConnect = { requested = AppPage.Connect },
                onSettings = ::openSettings,
                onAbout = { requested = AppPage.About },
                onDonate = { requested = AppPage.Donate },
            )

            // Back from every hub page lands on the menu, which is what Flutter's
            // Navigator.push gave for free.
            AppPage.Connect -> {
                BackHandler { requested = AppPage.Menu }
                ConnectionScreen(viewModel = coordinator.viewModel)
            }

            AppPage.Settings -> {
                BackHandler { requested = AppPage.Menu }
                SettingsScreen(
                    viewModel = coordinator.settingsViewModel,
                    onBack = ::closeSettings,
                )
            }

            AppPage.About -> {
                BackHandler { requested = AppPage.Menu }
                AboutScreen(
                    stars = coordinator.gitHubStars,
                    linkOpener = coordinator.linkOpener,
                    onBack = { requested = AppPage.Menu },
                )
            }

            AppPage.Donate -> {
                BackHandler { requested = AppPage.Menu }
                DonateScreen(
                    linkOpener = coordinator.linkOpener,
                    onBack = { requested = AppPage.Menu },
                )
            }
        }
    }
}
