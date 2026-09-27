package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.data.services.DashboardInput
import dev.fazrigading.wheeldeck.data.services.GamePreset
import dev.fazrigading.wheeldeck.data.services.InputMapping
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.SteeringState
import dev.fazrigading.wheeldeck.ui.features.driving.view_models.DrivingViewModel
import dev.fazrigading.wheeldeck.ui.features.settings.views.BindingEditDialog
import dev.fazrigading.wheeldeck.ui.features.settings.views.controlLabel

/// The driving surface: the rotatable dashboard grid, the gyro tilt readout, and
/// the calibration gate.
///
/// The grid carries the wheel, the pedals, and the camera pad, so the screen
/// only adds what the layout cannot place. The tilt readout rides on top in
/// gyro mode only, where there is no wheel rotation to read from.
@Composable
fun DrivingScreen(
    viewModel: DrivingViewModel,
    pedals: PedalInput,
    dashboardInput: DashboardInput,
    modifier: Modifier = Modifier,
    onOpenSettings: () -> Unit = {},
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val pedalState by pedals.state.collectAsStateWithLifecycle()
    val gateState by viewModel.sendGate.state.collectAsStateWithLifecycle()
    var binding by remember { mutableStateOf<ControlId?>(null) }
    val bindings by viewModel.bindings.collectAsStateWithLifecycle()
    val bindingFor: (ControlId) -> String = remember(bindings) {
        { control -> bindings[control] ?: GamePreset.UNBOUND }
    }

    LaunchedEffect(Unit) { viewModel.init() }

    // Tapping a dead cell opens the binder, the same dialog the Keybind
    // Configuration page uses, so a control can be bound without leaving Driving.
    fun openBinder(control: ControlId) {
        binding = control
    }

    Box(modifier = modifier.fillMaxSize()) {
        // A lifecycle interruption pauses the session and re-arms the gate, so
        // the driver re-confirms the center before input flows again (ADR-0002).
        if (state.awaitingCalibration) {
            CalibrationGate(steering = state.steering, onConfirmed = viewModel::confirmCalibration)
            return@Box
        }

        BlockGrid(
            layout = state.layout,
            env = GridEnv(
                input = dashboardInput,
                bindingFor = bindingFor,
                pedals = pedals,
                pedalState = pedalState,
                gate = viewModel.sendGate,
                gateState = gateState,
                degrees = state.rotationDegree,
                springBack = state.springBack,
                onSteering = viewModel::setRotatableSteering,
                onCameraPadModeSwitch = viewModel::toggleCameraPadMode,
                cameraPadMode = state.cameraPadMode,
                engineStartMode = state.engineStartMode,
                onBindRequested = ::openBinder,
            ),
        )

        if (!state.isRotatable) {
            TiltReadout(
                angle = state.steering.angle,
                modifier = Modifier.align(Alignment.TopCenter).padding(top = 8.dp),
            )
        }

        // A small target in the corner: the driving surface is all gesture, so
        // there is no bar to hang settings off.
        SettingsButton(
            onClick = onOpenSettings,
            modifier = Modifier.align(Alignment.TopEnd).padding(8.dp),
        )

        binding?.let { control ->
            BindingEditDialog(
                title = controlLabel(control),
                current = viewModel.bindingFor(control),
                isGamepad = state.mapping == InputMapping.Gamepad,
                onSave = { value ->
                    viewModel.setBinding(control, value)
                    binding = null
                },
                onDismiss = { binding = null },
            )
        }
    }
}

/// Shown after a lifecycle interruption, requiring the driver to re-confirm the
/// steering center before input resumes. Rotatable steering resumes directly,
/// so the gate only ever appears in gyro mode.
@Composable
fun CalibrationGate(steering: SteeringState, onConfirmed: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Session interrupted", style = MaterialTheme.typography.headlineSmall)
        Text(
            text = "The connection was paused. Please re-confirm\nyour steering center before resuming.",
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            text = "Current steering angle: ${"%.2f".format(steering.angle)}",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(top = 24.dp),
        )
        FilledTonalButton(onClick = onConfirmed, modifier = Modifier.padding(top = 24.dp)) {
            Text("Resume driving")
        }
    }
}

/// The settings entry point, a small icon in the corner of the driving surface.
@Composable
private fun SettingsButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    IconButton(
        onClick = onClick,
        modifier = modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(Color(0xFF37474F)),
    ) {
        Icon(
            Icons.Filled.Settings,
            contentDescription = "Settings",
            tint = Color.White,
            modifier = Modifier.size(22.dp),
        )
    }
}
