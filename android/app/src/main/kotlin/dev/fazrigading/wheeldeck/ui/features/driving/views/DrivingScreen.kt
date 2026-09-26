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
import dev.fazrigading.wheeldeck.domain.models.SteeringState
import dev.fazrigading.wheeldeck.ui.features.driving.view_models.DrivingUiState
import dev.fazrigading.wheeldeck.ui.features.driving.view_models.DrivingViewModel

/// The driving surface: a steering surface, the pedal bars, the camera pad, and
/// the calibration gate.
///
/// Gyro mode shows the tilting wheel and a tilt readout; rotatable mode shows
/// the finger-drag wheel. The dashboard grid lands with the layout engine
/// (Task 11), so the controls reachable here are the camera pad's.
@Composable
fun DrivingScreen(
    viewModel: DrivingViewModel,
    pedals: PedalInput,
    dashboardInput: DashboardInput,
    modifier: Modifier = Modifier,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { viewModel.init() }

    Box(modifier = modifier.fillMaxSize()) {
        // A lifecycle interruption pauses the session and re-arms the gate, so
        // the driver re-confirms the center before input flows again (ADR-0002).
        if (state.awaitingCalibration) {
            CalibrationGate(steering = state.steering, onConfirmed = viewModel::confirmCalibration)
        } else {
            DrivingControls(
                state = state,
                viewModel = viewModel,
                pedals = pedals,
                dashboardInput = dashboardInput,
            )
        }
    }
}

@Composable
private fun DrivingControls(
    state: DrivingUiState,
    viewModel: DrivingViewModel,
    pedals: PedalInput,
    dashboardInput: DashboardInput,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(12.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        if (state.isRotatable) {
            Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
                RotatableWheel(
                    degrees = state.rotationDegree,
                    springBack = state.springBack,
                    onChanged = viewModel::setRotatableSteering,
                    diameter = 240.dp,
                )
            }
        } else {
            Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) {
                // Horizontal drag is the fallback when the gyro is unavailable or
                // unwanted; ending the drag re-centers the sensor on the angle
                // the finger left it at.
                WheelView(
                    angle = state.steering.angle,
                    size = 240.dp,
                    modifier = Modifier.pointerInput(Unit) {
                        detectHorizontalDragGestures(
                            onDragStart = { viewModel.onWheelDragStart() },
                            onHorizontalDrag = { change, dx ->
                                change.consume()
                                viewModel.onWheelDragUpdate(dx.toDouble())
                            },
                            onDragEnd = { viewModel.onWheelDragEnd() },
                            onDragCancel = { viewModel.onWheelDragEnd() },
                        )
                    },
                )
            }
            TiltReadout(
                angle = state.steering.angle,
                modifier = Modifier.align(Alignment.CenterHorizontally),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth().height(200.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PedalPanel(input = pedals, modifier = Modifier.weight(1f).fillMaxSize())
            CameraPad(
                mode = state.cameraPadMode,
                input = dashboardInput,
                // The preset tables land with Task 12; unbound cells send
                // nothing, which is the safe side until then.
                bindingFor = { "" },
                onModeSwitch = viewModel::toggleCameraPadMode,
                modifier = Modifier.weight(1f).fillMaxSize(),
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
