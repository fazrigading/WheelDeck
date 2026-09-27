package dev.fazrigading.wheeldeck.ui.features.connection.views

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.domain.models.ConnectionStatus
import dev.fazrigading.wheeldeck.domain.models.DiscoveredServer
import dev.fazrigading.wheeldeck.ui.features.connection.view_models.ConnectionUiState
import dev.fazrigading.wheeldeck.ui.features.connection.view_models.ConnectionViewModel

/// M3 Connect screen: status card, paired/unpaired discovery lists, FAB manual add.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConnectionScreen(viewModel: ConnectionViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var manualAddOpen by remember { mutableStateOf(false) }

    if (manualAddOpen) {
        ModalBottomSheet(onDismissRequest = { manualAddOpen = false }) {
            ManualAddSheetContent(
                viewModel = viewModel,
                onDismiss = { manualAddOpen = false },
            )
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Connect to WheelDeck") },
                actions = {
                    FilledTonalIconButton(onClick = { viewModel.refreshDiscoveryAsync() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = "Refresh")
                    }
                    if (state.status != ConnectionStatus.Disconnected) {
                        IconButton(onClick = { viewModel.disconnect() }) {
                            Icon(Icons.Filled.WifiOff, contentDescription = "Disconnect")
                        }
                    }
                },
            )
        },
        floatingActionButton = {
            if (state.pairingChallenge == null) {
                ExtendedFloatingActionButton(
                    onClick = { manualAddOpen = true },
                    icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                    text = { Text("Add IP") },
                )
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            ConnectionStatusCard(
                status = state.status,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
            )
            if (state.status == ConnectionStatus.Reconnecting) {
                Text(
                    "Connection unsuccessful. Check that the desktop app is running " +
                        "and both devices are on the same Wi-Fi, or tap Add IP below.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
            Spacer(Modifier.height(16.dp))
            if (state.pairingChallenge != null) {
                PairingModal(
                    error = state.pairingError,
                    onSubmit = viewModel::submitPairingCode,
                    onCancel = { viewModel.disconnect() },
                )
            } else {
                DiscoveryList(viewModel = viewModel, state = state)
            }
        }
    }
}

/// Tinted status card — progress spinner for transient states.
@Composable
fun ConnectionStatusCard(status: ConnectionStatus, modifier: Modifier = Modifier) {
    val cs = MaterialTheme.colorScheme

    data class Appearance(val bg: Color, val fg: Color, val iconBg: Color, val icon: ImageVector, val label: String, val subtitle: String)

    val look = when (status) {
        ConnectionStatus.Connected -> Appearance(cs.primaryContainer, cs.onPrimaryContainer, cs.primary, Icons.Filled.Wifi, "Connected", "Ready to drive")
        ConnectionStatus.Connecting -> Appearance(cs.secondaryContainer, cs.onSecondaryContainer, cs.secondary, Icons.Filled.Sync, "Connecting…", "Establishing link…")
        ConnectionStatus.PairingRequired -> Appearance(cs.tertiaryContainer, cs.onTertiaryContainer, cs.tertiary, Icons.Filled.Key, "Pairing required", "Enter PIN to pair")
        ConnectionStatus.Reconnecting -> Appearance(cs.errorContainer, cs.onErrorContainer, cs.error, Icons.Filled.Sync, "Reconnecting…", "Trying again…")
        ConnectionStatus.Discovering -> Appearance(cs.secondaryContainer, cs.onSecondaryContainer, cs.secondary, Icons.Filled.Sync, "Searching…", "Scanning local network…")
        ConnectionStatus.Disconnected -> Appearance(cs.surfaceContainerHighest, cs.onSurfaceVariant, cs.outline, Icons.Filled.WifiOff, "Disconnected", "Tap a receiver or add IP")
    }
    val isTransient = status == ConnectionStatus.Connecting ||
        status == ConnectionStatus.Reconnecting ||
        status == ConnectionStatus.Discovering

    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = look.bg),
        shape = RoundedCornerShape(16.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                look.icon,
                contentDescription = null,
                tint = look.fg,
                modifier = Modifier
                    .size(40.dp)
                    .background(look.iconBg.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                    .padding(8.dp),
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(look.label, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = look.fg)
                Text(look.subtitle, style = MaterialTheme.typography.bodySmall, color = look.fg.copy(alpha = 0.8f))
            }
            if (isTransient) {
                CircularProgressIndicator(color = look.fg, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun DiscoveryList(viewModel: ConnectionViewModel, state: ConnectionUiState) {
    if (state.servers.isEmpty()) {
        EmptyState(onScanAgain = { viewModel.refreshDiscoveryAsync() })
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (state.pairedServers.isNotEmpty()) {
            item { SectionHeader("Paired devices") }
            items(state.pairedServers, key = { "${it.host}:${it.port}" }) { server ->
                var confirmRemove by remember { mutableStateOf(false) }
                ServerCard(
                    server = server,
                    container = MaterialTheme.colorScheme.primaryContainer,
                    onContainer = MaterialTheme.colorScheme.onPrimaryContainer,
                    subtitle = "Tap to reconnect · hold to remove",
                    trailing = { Icon(Icons.Filled.Verified, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp)) },
                    onClick = { viewModel.connect(server.toConnectionTarget()) },
                    onLongClick = { confirmRemove = true },
                )
                if (confirmRemove) {
                    AlertDialog(
                        onDismissRequest = { confirmRemove = false },
                        title = { Text("Remove ${server.name}?") },
                        text = { Text("You will need to pair again with a new PIN.") },
                        confirmButton = {
                            TextButton(onClick = {
                                confirmRemove = false
                                viewModel.forgetPaired(server)
                            }) { Text("Remove") }
                        },
                        dismissButton = {
                            TextButton(onClick = { confirmRemove = false }) { Text("Cancel") }
                        },
                    )
                }
            }
        }
        item {
            SectionHeader(if (state.pairedServers.isNotEmpty()) "Available on this Wi-Fi" else "Receivers on this Wi-Fi")
        }
        if (state.unpairedServers.isEmpty() && state.pairedServers.isNotEmpty()) {
            item {
                Card {
                    Text(
                        "No new receivers found.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(16.dp),
                    )
                }
            }
        } else {
            items(state.unpairedServers, key = { "${it.host}:${it.port}" }) { server ->
                ServerCard(
                    server = server,
                    container = MaterialTheme.colorScheme.secondaryContainer,
                    onContainer = MaterialTheme.colorScheme.onSecondaryContainer,
                    subtitle = "Tap to connect – PIN required",
                    trailing = { Icon(Icons.Filled.ChevronRight, contentDescription = null) },
                    onClick = { viewModel.connect(server.toConnectionTarget()) },
                )
            }
        }
    }
}

@Composable
private fun SectionHeader(label: String) {
    Text(
        label,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun ServerCard(
    server: DiscoveredServer,
    container: Color,
    onContainer: Color,
    subtitle: String,
    trailing: @Composable () -> Unit,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
) {
    // Card(onClick) builds its own clickable; a long-press card needs the
    // surface overload plus combinedClickable instead.
    if (onLongClick != null) {
        Card(modifier = Modifier.combinedClickable(onClick = onClick, onLongClick = onLongClick)) {
            ServerCardContent(server, container, onContainer, subtitle, trailing)
        }
    } else {
        Card(onClick = onClick) {
            ServerCardContent(server, container, onContainer, subtitle, trailing)
        }
    }
}

@Composable
private fun ServerCardContent(
    server: DiscoveredServer,
    container: Color,
    onContainer: Color,
    subtitle: String,
    trailing: @Composable () -> Unit,
) {
    Row(
        modifier = Modifier.padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Filled.Computer,
            contentDescription = null,
            tint = onContainer,
            modifier = Modifier
                .size(40.dp)
                .background(container, RoundedCornerShape(12.dp))
                .padding(8.dp),
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(server.name, fontWeight = FontWeight.SemiBold)
            Text("${server.host}:${server.port}\n$subtitle", style = MaterialTheme.typography.bodySmall)
        }
        trailing()
    }
}

@Composable
private fun EmptyState(onScanAgain: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Filled.SearchOff,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(40.dp),
        )
        Spacer(Modifier.height(16.dp))
        Text("No receivers found", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(
            "Make sure the desktop app is running\non the same Wi-Fi.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(16.dp))
        FilledTonalButton(onClick = onScanAgain) {
            Icon(Icons.Filled.Refresh, contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text("Scan again")
        }
    }
}

/// PIN entry modal (2FA-style 6-digit input); auto-submits at 6 digits.
/// Shown only while a pairing challenge is active — a disconnect from any
/// path dismisses it, so the prompt can never go stale.
@Composable
private fun PairingModal(error: Boolean, onSubmit: (String) -> Unit, onCancel: () -> Unit) {
    var pin by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text("Pairing required") },
        text = {
            Column {
                Text(
                    "Enter PIN from Pairing menu > Generate Code button on the desktop",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(Modifier.height(16.dp))
                OutlinedTextField(
                    value = pin,
                    onValueChange = { input ->
                        val digits = input.filter(Char::isDigit).take(6)
                        pin = digits
                        if (digits.length == 6) onSubmit(digits)
                    },
                    label = { Text("PIN") },
                    singleLine = true,
                    isError = error,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    modifier = Modifier.fillMaxWidth(),
                )
                if (error) {
                    Spacer(Modifier.height(8.dp))
                    Text("PIN incorrect. Try again.", color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onCancel) { Text("Cancel") }
        },
    )
}
