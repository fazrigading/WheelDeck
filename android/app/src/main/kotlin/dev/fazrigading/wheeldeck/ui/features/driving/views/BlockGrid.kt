package dev.fazrigading.wheeldeck.ui.features.driving.views

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.fazrigading.wheeldeck.data.services.CameraPadMode
import dev.fazrigading.wheeldeck.data.services.CellRect
import dev.fazrigading.wheeldeck.data.services.DashboardInput
import dev.fazrigading.wheeldeck.data.services.DashboardGateState
import dev.fazrigading.wheeldeck.data.services.DashboardSendGate
import dev.fazrigading.wheeldeck.data.services.DrivingLayout
import dev.fazrigading.wheeldeck.data.services.EngineStartMode
import dev.fazrigading.wheeldeck.data.services.LayoutSlot
import dev.fazrigading.wheeldeck.data.services.LightStage
import dev.fazrigading.wheeldeck.data.services.PedalInput
import dev.fazrigading.wheeldeck.data.services.SlotKind
import dev.fazrigading.wheeldeck.domain.models.ControlId
import dev.fazrigading.wheeldeck.domain.models.PedalState
import dev.fazrigading.wheeldeck.domain.models.PedalType
import dev.fazrigading.wheeldeck.ui.core.ControlMode
import dev.fazrigading.wheeldeck.ui.core.ControlPress

/// Everything a slot needs from the driving session, gathered so the grid and
/// its slots take one argument instead of a dozen.
data class GridEnv(
    val input: DashboardInput,
    val bindingFor: (ControlId) -> String,
    val pedals: PedalInput,
    val pedalState: PedalState,
    val gate: DashboardSendGate?,
    val gateState: DashboardGateState,
    val degrees: Int,
    val springBack: Boolean,
    val onSteering: (Double) -> Unit,
    val onCameraPadModeSwitch: () -> Unit,
    /// Called when a driver taps a cell that has no binding, so the app can offer
    /// the binder instead of a dead button. The default ignores the tap, which
    /// leaves those cells dead.
    val onBindRequested: (ControlId) -> Unit = {},
    val cameraPadMode: CameraPadMode = CameraPadMode.fallback,
    val engineStartMode: EngineStartMode = EngineStartMode.fallback,
    val shownPedals: Set<PedalType> = setOf(PedalType.Clutch, PedalType.Brake, PedalType.Accelerator),
)

/// The rotatable dashboard: the six blocks of the global grid, padded away from
/// their neighbours but flush with the screen edges (TODO.md Dashboard 3).
///
/// Every box comes from the [DrivingLayout], so a preset change is a data
/// change; the slots below only place what the layout says.
@Composable
fun BlockGrid(
    layout: DrivingLayout,
    env: GridEnv,
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val widthPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }
        val blockPadding = with(density) { BlockGeometry.BLOCK_PADDING_PX.dp.toPx() }
        val cell = BlockGeometry.cellSize(widthPx, heightPx)

        DrivingLayout.blocks.forEach { block ->
            val blockBox = block.toPaddedPixels(widthPx, heightPx, blockPadding)
            Placed(blockBox.left, blockBox.top, blockBox.width, blockBox.height) {
                layout.slotsIn(block).forEach { slot ->
                    val box = slot.rect.toPixels(widthPx, heightPx, cell)
                    Placed(
                        left = box.left - blockBox.left,
                        top = box.top - blockBox.top,
                        width = box.width,
                        height = box.height,
                    ) {
                        SlotContent(slot = slot, box = box, env = env)
                    }
                }
            }
        }
    }
}

/// A child placed at an absolute pixel offset inside its parent.
@Composable
private fun Placed(
    left: Float,
    top: Float,
    width: Float,
    height: Float,
    content: @Composable () -> Unit,
) {
    val density = LocalDensity.current
    Box(
        Modifier.offset {
            IntOffset(
                with(density) { left.toDp().roundToPx() },
                with(density) { top.toDp().roundToPx() },
            )
        }.size(with(density) { width.toDp() }, with(density) { height.toDp() }),
    ) {
        content()
    }
}

@Composable
private fun SlotContent(slot: LayoutSlot, box: PixelRect, env: GridEnv) {
    val pedalState = env.pedalState
    when (slot.kind) {
        SlotKind.Wheel -> {
            val wheel = remember(box) { wheelBox(box) }
            Placed(
                left = wheel.left - box.left,
                top = wheel.top - box.top,
                width = wheel.width,
                height = wheel.height,
            ) {
                RotatableWheel(
                    degrees = env.degrees,
                    springBack = env.springBack,
                    onChanged = env.onSteering,
                    // The placed box already carries the wheel's square size.
                    diameter = Dp.Unspecified,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        SlotKind.CameraPad -> CameraPad(
            mode = env.cameraPadMode,
            input = env.input,
            bindingFor = env.bindingFor,
            onModeSwitch = env.onCameraPadModeSwitch,
            onBindRequested = env.onBindRequested,
            modifier = Modifier.fillMaxSize(),
        )
        // A hidden pedal renders nothing, as in the Dart grid.
        SlotKind.Pedal -> slot.pedal?.takeIf { it in env.shownPedals }?.let { pedal ->
            PedalBar(
                pedal = pedal,
                pressure = pedalState[pedal],
                onDrag = env.pedals::setPressure,
                onRelease = env.pedals::release,
                modifier = Modifier.fillMaxSize(),
            )
        }
        // TODO.md Dashboard 2: the accelerator and brake share this slot.
        SlotKind.PedalGroup -> if (
            PedalType.Brake in env.shownPedals && PedalType.Accelerator in env.shownPedals
        ) {
            val gap = with(LocalDensity.current) { BlockGeometry.CELL_PADDING_PX.dp.toPx() }
            val (brakeBox, acceleratorBox) = remember(box, gap) { pedalGroupBars(box, gap) }
            Placed(
                left = brakeBox.left - box.left,
                top = brakeBox.top - box.top,
                width = brakeBox.width,
                height = brakeBox.height,
            ) {
                PedalBar(
                    pedal = PedalType.Brake,
                    pressure = pedalState[PedalType.Brake],
                    onDrag = env.pedals::setPressure,
                    onRelease = env.pedals::release,
                    modifier = Modifier.fillMaxSize(),
                )
            }
            Placed(
                left = acceleratorBox.left - box.left,
                top = acceleratorBox.top - box.top,
                width = acceleratorBox.width,
                height = acceleratorBox.height,
            ) {
                PedalBar(
                    pedal = PedalType.Accelerator,
                    pressure = pedalState[PedalType.Accelerator],
                    onDrag = env.pedals::setPressure,
                    onRelease = env.pedals::release,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        SlotKind.Hole -> ReservedCell()
        // Every button slot renders: the grid's placement is the visibility
        // rule, and the send gate drops the unbound ones.
        SlotKind.Button, SlotKind.GearUp, SlotKind.GearDown -> slot.control?.let { control ->
            DashboardControl(
                control = control,
                mode = modeFor(control, env.engineStartMode),
                input = env.input,
                bindingFor = env.bindingFor,
                onBindRequested = env.onBindRequested,
                gate = env.gate,
                gateState = env.gateState,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

/// A reserved cell: rendered disabled, like an unbound control.
@Composable
private fun ReservedCell() {
    Box(
        Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF37474F))
            .border(2.dp, Color(0xFF90A4AE), RoundedCornerShape(12.dp))
            .semantics { contentDescription = "Reserved cell" },
    )
}

/// The interaction mode of a grid cell. Engine start follows the setting; every
/// other control uses the ported table.
fun modeFor(control: ControlId, engineStartMode: EngineStartMode): ControlMode = when (control) {
    ControlId.EngineStart -> when (engineStartMode) {
        EngineStartMode.HoldConfirm -> ControlMode.HoldConfirm
        EngineStartMode.SinglePress -> ControlMode.Momentary
    }
    else -> ControlPress.modeFor(control)
}

/// A control cell: press, hold, and gate-driven visuals.
@Composable
fun DashboardControl(
    control: ControlId,
    mode: ControlMode,
    input: DashboardInput,
    bindingFor: (ControlId) -> String,
    modifier: Modifier = Modifier,
    gate: DashboardSendGate? = null,
    gateState: DashboardGateState = DashboardGateState(),
    onBindRequested: (ControlId) -> Unit = {},
) {
    val scope = rememberCoroutineScope()
    val press = remember(control, mode) {
        ControlPress(
            mode = mode,
            control = control,
            activate = { c, a -> input.activate(c, a) },
            scope = scope,
        )
    }
    val pressed by press.pressed.collectAsState()
    val live = !DashboardSendGate.isUnbound(bindingFor(control))
    // Signals and hazard read the gate's blink phase; everything else reads its
    // own pressed state.
    val lit = when (control) {
        ControlId.TurnSignalLeft, ControlId.TurnSignalRight, ControlId.HazardLights ->
            gate != null && gate.signalVisualActive(control)
        else -> pressed
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                when {
                    !live -> Color(0xFF37474F)
                    lit -> Color(0xFFFFB300)
                    else -> Color(0xFF455A64)
                },
            )
            .border(
                width = if (lit && live) 3.dp else 2.dp,
                color = if (lit && live) Color(0xFFFFE082) else Color(0xFF90A4AE),
                shape = RoundedCornerShape(12.dp),
            )
            .semantics { contentDescription = "dashboard-${control.wireValue}" }
            .pointerInput(press, live) {
                detectTapGestures(
                    onPress = {
                        if (!live) return@detectTapGestures
                        press.onPressDown()
                        if (tryAwaitRelease()) press.onPressUp() else press.onPressCancel()
                    },
                    // A dead cell is the driver's cue to bind it, so tapping one
                    // opens the binder rather than doing nothing at all.
                    onTap = { if (live) press.onTap() else onBindRequested(control) },
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = cellLabel(control, gateState),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = if (lit && live) Color.Black else Color.White,
            maxLines = 1,
        )
        if (!live) {
            Text(
                text = "—",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.align(Alignment.TopEnd).padding(2.dp),
            )
        }
    }
}

/// What a cell prints: the headlight cycle shows its stage, the rest their short
/// label, falling back to the wire value for a control with no label.
fun cellLabel(control: ControlId, gateState: DashboardGateState): String =
    if (control == ControlId.HeadlightToggle) {
        when (gateState.lightStage) {
            LightStage.Off -> "OFF"
            LightStage.Parking -> "PARK"
            LightStage.Low -> "LOW"
        }
    } else {
        CELL_LABELS[control] ?: control.wireValue
    }

/// Short labels for the cells a driver reads at a glance, ported from
/// `DashboardPanel.labelFor`. The signal cells print an arrow, matching the
/// icons the Dart grid drew for them: their wire values do not fit a 1x1 cell.
private val CELL_LABELS: Map<ControlId, String> = buildMap {
    put(ControlId.TurnSignalLeft, "◀")
    put(ControlId.TurnSignalRight, "▶")
    put(ControlId.HighBeamToggle, "BEAM")
    put(ControlId.CruiseToggle, "CRUISE")
    put(ControlId.CruiseSetResume, "RESUME")
    put(ControlId.ParkingBrake, "PARK")
    put(ControlId.Wipers, "WIPE")
    put(ControlId.EngineStart, "START")
    put(ControlId.HazardLights, "HAZARD")
    put(ControlId.BeaconLights, "BEACON")
    put(ControlId.Flasher, "FLASH")
    put(ControlId.Horn, "HORN")
    put(ControlId.Trailer, "TRAILER")
    put(ControlId.LiftDropAxle, "AXLE")
    put(ControlId.CameraView, "CAM")
    put(ControlId.GearUp, "GEAR+")
    put(ControlId.GearDown, "GEAR-")
    put(ControlId.EngineBrake, "E-BRK")
    put(ControlId.AirHorn, "AIR")
    put(ControlId.DifferentialLock, "DIFF")
    put(ControlId.RetarderIncrease, "RET+")
    put(ControlId.RetarderDecrease, "RET-")
    put(ControlId.QuickInfo, "INFO")
    put(ControlId.MirrorToggle, "MIRROR")
    put(ControlId.HudWidgets, "HUD")
    put(ControlId.VehicleAdjustment, "VEH")
    put(ControlId.NavigationZoomOut, "NAV")
    put(ControlId.WidgetOptions, "WIDGET")
    put(ControlId.Services, "SVC")
    put(ControlId.QuickSave, "SAVE")
    put(ControlId.QuickLoad, "LOAD")
    put(ControlId.Screenshot, "SHOT")
    put(ControlId.GarageManager, "GARAGE")
    put(ControlId.AudioPlayer, "AUDIO")
}
