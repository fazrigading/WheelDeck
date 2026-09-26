package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.fazrigading.wheeldeck.data.services.DashboardInput
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.SteeringState
import dev.fazrigading.wheeldeck.ui.features.driving.view_models.DrivingViewModel

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
    bindingFor: (ControlId) -> String = { "" },
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    val pedalState by pedals.state.collectAsStateWithLifecycle()
    val gateState by viewModel.sendGate.state.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { viewModel.init() }

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
            ),
        )

        if (!state.isRotatable) {
            TiltReadout(
                angle = state.steering.angle,
                modifier = Modifier.align(Alignment.TopCenter).padding(top = 8.dp),
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
