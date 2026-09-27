package dev.fazrigading.wheeldeck.ui.features.settings.views

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.ui.features.settings.view_models.SettingsViewModel
import kotlinx.coroutines.launch

/// The Keybind Configuration page (TODO.md Settings).
///
/// One row per control showing the binding for the active mapping mode; tapping
/// opens [BindingEditDialog]. The values shown are the *effective* bindings —
/// the stored override, or the game preset's default — so a driver sees what the
/// desktop will actually receive, and the dash on an unbound row is the same one
/// the send gate drops.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KeybindConfigurationScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var editing by remember { mutableStateOf<ControlId?>(null) }
    val isGamepad = state.mapping == InputMapping.Gamepad

    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(if (isGamepad) "Gamepad buttons" else "Key bindings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        if (!state.loaded) return@Scaffold
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            item {
                Text(
                    "Tap a control to set its ${if (isGamepad) "button" else "key"}. " +
                        "Clear a value to leave the control unbound — the phone then sends nothing.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp),
                )
            }
            items(ControlId.entries, key = { it.name }) { control ->
                val binding = viewModel.bindingFor(control)
                ListItem(
                    headlineContent = { Text(controlLabel(control)) },
                    trailingContent = {
                        AssistChip(
                            onClick = { editing = control },
                            label = { Text(binding.takeIf { it.isNotEmpty() } ?: "—") },
                        )
                    },
                    modifier = Modifier.clickable { editing = control },
                )
            }
        }
    }

    editing?.let { control ->
        BindingEditDialog(
            title = controlLabel(control),
            current = viewModel.bindingFor(control),
            isGamepad = isGamepad,
            onSave = { value ->
                viewModel.setBinding(control, value)
                editing = null
                scope.launch {
                    snackbar.showSnackbar(
                        if (DashboardSendGate.isUnbound(value)) {
                            "${controlLabel(control)} is now unbound"
                        } else {
                            "${controlLabel(control)} → $value"
                        },
                    )
                }
            },
            onDismiss = { editing = null },
        )
    }
}
