package dev.fazrigading.wheeldeck.ui.features.onboarding.views

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ScreenRotation
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.data.services.PermissionStatus
import dev.fazrigading.wheeldeck.ui.features.onboarding.view_models.OnboardingViewModel
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch

/// First-run onboarding: explains the two permissions the app wants, then
/// requests them.
///
/// Denial is not a dead end — a denied sensor still drives the rotatable wheel,
/// and a denied network still reaches a manually-entered desktop — so "Continue"
/// and "Skip for now" both finish, and the screen appears only once.
@Composable
fun OnboardingScreen(
    viewModel: OnboardingViewModel,
    onComplete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceEvenly,
    ) {
        Icon(
            Icons.Filled.ScreenRotation,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Text("Welcome to WheelDeck", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Turn your phone into a steering wheel\nand dashboard for PC simulators.",
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyLarge,
        )

        PermissionTile(
            icon = Icons.Filled.ScreenRotation,
            title = "Motion sensor",
            description = "Reads your phone's gyroscope to map steering rotation.",
            status = state.motionSensorStatus,
        )
        PermissionTile(
            icon = Icons.Filled.Wifi,
            title = "Local network",
            description = "Discovers and connects to the WheelDeck desktop server.",
            status = state.localNetworkStatus,
        )

        Column(modifier = Modifier.fillMaxWidth()) {
            Button(
                onClick = {
                    scope.launch {
                        viewModel.requestAndComplete()
                        onComplete()
                    }
                },
                enabled = !state.requesting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.requesting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                    )
                } else {
                    Text("Continue")
                }
            }
            TextButton(
                onClick = {
                    scope.launch {
                        viewModel.complete()
                        onComplete()
                    }
                },
                enabled = !state.requesting,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Skip for now") }
        }
    }
}

/// One permission row: what it is for, and how the request ended. A null status
/// means not asked yet.
@Composable
private fun PermissionTile(
    icon: ImageVector,
    title: String,
    description: String,
    status: PermissionStatus?,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Column(modifier = Modifier.weight(1f)) {
                Text(title)
                Text(
                    description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            when (status) {
                PermissionStatus.Granted -> Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = "Granted",
                    tint = Color.Green,
                )
                PermissionStatus.Denied -> Icon(
                    Icons.Filled.Cancel,
                    contentDescription = "Denied",
                    tint = MaterialTheme.colorScheme.error,
                )
                PermissionStatus.PermanentlyDenied -> Icon(
                    Icons.Filled.Block,
                    contentDescription = "Blocked",
                    tint = MaterialTheme.colorScheme.error,
                )
                null -> Unit
            }
        }
    }
}
