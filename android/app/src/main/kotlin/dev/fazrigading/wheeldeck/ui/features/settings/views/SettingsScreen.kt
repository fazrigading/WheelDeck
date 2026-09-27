package dev.fazrigading.wheeldeck.ui.features.settings.views

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.data.services.CameraControlType
import dev.fazrigading.wheeldeck.data.services.DashboardVisibility
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.PedalSide
import dev.fazrigading.wheeldeck.data.services.RotationDegree
import dev.fazrigading.wheeldeck.data.services.WheelMode
import dev.fazrigading.wheeldeck.domain.models.PedalType
import dev.fazrigading.wheeldeck.ui.features.settings.view_models.SettingsSection
import dev.fazrigading.wheeldeck.ui.features.settings.view_models.SettingsUiState
import dev.fazrigading.wheeldeck.ui.features.settings.view_models.SettingsViewModel
import dev.fazrigading.wheeldeck.ui.features.settings.view_models.settingsSections
import kotlinx.coroutines.launch

/// The settings page.
///
/// The sections come from [settingsSections], so the visibility rules stay in one
/// testable place rather than in a chain of composable `if`s. Bindings live on
/// their own page ([KeybindConfigurationScreen]) — TODO.md Settings asks for a
/// dedicated page, and a 92-row list has no place in this one.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var confirmingReset by remember { mutableStateOf(false) }
    var showKeybinds by remember { mutableStateOf(false) }

    // A second page rather than a long list: TODO.md Settings. Back from the
    // keybind page returns here, so the settings state is never rebuilt.
    if (showKeybinds) {
        KeybindConfigurationScreen(viewModel, onBack = { showKeybinds = false })
        return
    }

    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
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
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            for (section in settingsSections(state)) {
                item(key = section.name) {
                    SettingsSectionContent(
                        section = section,
                        state = state,
                        viewModel = viewModel,
                        onOpenKeybinds = { showKeybinds = true },
                        onConfirmReset = { confirmingReset = true },
                    )
                }
            }
        }
    }

    if (confirmingReset) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { confirmingReset = false },
            title = { Text("Reset to defaults?") },
            text = {
                Text(
                    "Restores gamepad input, the ETS2 preset, rotatable 900°, hidden clutch, " +
                        "shown dashboard, default pedal sides, and rotate-back-to-zero.",
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirmingReset = false
                        viewModel.resetToDefaults()
                        scope.launch { snackbar.showSnackbar("Reset to defaults") }
                    },
                ) { Text("Reset") }
            },
            dismissButton = {
                TextButton(onClick = { confirmingReset = false }) { Text("Cancel") }
            },
        )
    }
}

/// One settings section, rendered by [settingsSections] so the visibility rules
/// live in one testable place rather than a chain of composable `if`s.
@Composable
private fun SettingsSectionContent(
    section: SettingsSection,
    state: SettingsUiState,
    viewModel: SettingsViewModel,
    onOpenKeybinds: () -> Unit,
    onConfirmReset: () -> Unit,
) {
    when (section) {
        SettingsSection.InputMode -> sectionTitle("Input mode") {
            choice(
                InputMapping.entries,
                state.mapping,
                { it.label() }) { viewModel.selectMapping(it) }
            text(
                if (state.mapping == InputMapping.Gamepad) {
                    "Dashboard → virtual controller buttons"
                } else {
                    "Dashboard → ETS2 keybindings"
                },
            )
        }

        SettingsSection.GamePreset -> sectionTitle("Game preset") {
            choice(
                GamePreset.entries,
                state.preset,
                { it.label }) { viewModel.selectPreset(it) }
        }

        SettingsSection.WheelMode -> sectionTitle("Wheel mode") {
            choice(
                WheelMode.entries,
                state.wheelMode,
                { it.label }) { viewModel.selectWheelMode(it) }
            if (state.wheelMode == WheelMode.Rotatable) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (degree in RotationDegree.allowed) {
                        FilterChip(
                            selected = state.rotationDegree == degree,
                            onClick = { viewModel.selectRotationDegree(degree) },
                            label = { Text("$degree°") },
                        )
                    }
                }
                text("Finger rotation for full lock-to-lock.")
                toggleRow("Rotate back to zero", state.springBack, onChange = viewModel::selectSpringBack)
            } else {
                text("Gyro steering ignores rotation degrees.")
            }
        }

        SettingsSection.ShowControls -> sectionTitle("Show controls") {
            card {
                toggleRow("Clutch pedal", state.visibility.showClutch) {
                    viewModel.selectVisibility(state.visibility.copy(showClutch = it))
                }
                if (state.wheelMode == WheelMode.Gyro) {
                    toggleRow("Dashboard", state.visibility.showDashboard) {
                        viewModel.selectVisibility(state.visibility.copy(showDashboard = it))
                    }
                }
            }
        }

        SettingsSection.CameraControl -> sectionTitle("Camera control") {
            choice(
                CameraControlType.entries,
                state.cameraControlType,
                { it.label }) { viewModel.selectCameraControlType(it) }
        }

        SettingsSection.PedalSides -> sectionTitle("Pedal sides") {
            card {
                for (pedal in PedalType.entries) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(pedalLabel(pedal))
                        sideChoice(state.pedalSides.sideOf(pedal)) {
                            viewModel.selectPedalSide(pedal, it)
                        }
                    }
                }
            }
        }

        SettingsSection.EngineStart -> sectionTitle("Engine start") {
            choice(
                EngineStartMode.entries,
                state.engineStartMode,
                { it.label }) { viewModel.selectEngineStartMode(it) }
        }

        SettingsSection.DashboardControls -> sectionTitle("Dashboard controls") {
            card {
                for (control in DashboardVisibility.toggleable) {
                    toggleRow(
                        controlLabel(control),
                        control in state.visibleExtras,
                    ) { viewModel.toggleExtraControl(control) }
                }
            }
        }

        // A dedicated page, not a 92-row list: TODO.md Settings.
        SettingsSection.KeybindConfiguration -> sectionTitle("Keybind configuration") {
            card {
                ListItem(
                    headlineContent = { Text("Keybind configuration") },
                    supportingContent = {
                        text(
                            if (state.mapping == InputMapping.Gamepad) {
                                "Customize the virtual controller buttons."
                            } else {
                                "Customize the ETS2 keybindings."
                            },
                        )
                    },
                    trailingContent = {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
                    },
                    modifier = Modifier.clickable { onOpenKeybinds() },
                )
            }
        }

        SettingsSection.Reset -> OutlinedButton(
            onClick = { onConfirmReset() },
            modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
        ) {
            Icon(Icons.Filled.RestartAlt, contentDescription = null)
            Text("  Reset to default")
        }
    }
}

/// A labelled group on the settings page.
@Composable
private fun sectionTitle(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
        content()
    }
}

@Composable
private fun card(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Card(modifier = modifier.fillMaxWidth()) { Column { content() } }
}

@Composable
private fun text(body: String, modifier: Modifier = Modifier) {
    Text(
        body,
        modifier = modifier,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun toggleRow(
    title: String,
    checked: Boolean,
    modifier: Modifier = Modifier,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = MaterialTheme.typography.bodyLarge)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun <T> choice(
    options: List<T>,
    selected: T,
    label: (T) -> String,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    SingleChoiceSegmentedButtonRow(modifier = modifier.fillMaxWidth()) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = option == selected,
                onClick = { onSelect(option) },
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
            ) { Text(label(option)) }
        }
    }
}

@Composable
private fun sideChoice(
    selected: PedalSide,
    modifier: Modifier = Modifier,
    onSelect: (PedalSide) -> Unit,
) {
    SingleChoiceSegmentedButtonRow(modifier = modifier.width(180.dp)) {
        PedalSide.entries.forEachIndexed { index, side ->
            SegmentedButton(
                selected = side == selected,
                onClick = { onSelect(side) },
                shape = SegmentedButtonDefaults.itemShape(index, PedalSide.entries.size),
            ) { Text(if (side == PedalSide.Left) "Left" else "Right") }
        }
    }
}

private fun InputMapping.label() = if (this == InputMapping.Keyboard) "Keyboard" else "Gamepad"
