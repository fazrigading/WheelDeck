import 'package:flutter/material.dart';

import '../../../../data/services/camera_control_type.dart';
import '../../../../data/services/camera_pad_mode.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import '../../../../data/services/driving_layout.dart';
import '../../../../data/services/pedal_input.dart';
import 'camera_pad.dart';
import 'dashboard_panel.dart';
import 'pedal_panel.dart';
import 'rotatable_wheel.dart';

/// Renders a [DrivingLayout] as absolutely positioned slots on the global
/// 8x15 cell grid.
///
/// A single [LayoutBuilder] scales each slot's [CellRect] against the
/// available size and stacks the slot widgets: buttons (including the gear
/// 2x2 cells and the turn signals, which render as ordinary grid entries),
/// slot-sized pedal bars, the wheel, and disabled holes for controls that do
/// not exist yet. Camera-pad slots render the 3x3 pad widget.
/// lands.
class BlockGrid extends StatelessWidget {
  const BlockGrid({
    super.key,
    required this.layout,
    required this.input,
    required this.bindingFor,
    this.gate,
    required this.pedalInput,
    required this.shownPedals,
    required this.degrees,
    required this.onSteering,
    this.springBack = true,
    this.cameraPadMode = CameraPadMode.fallback,
    required this.onCameraPadModeSwitch,
    this.onBindRequested,
    this.cameraControlType = CameraControlType.dpad,
    this.onAnalog,
    this.editing = false,
    this.onEditIntent,
    this.editSlotWrapper,
  });

  final DrivingLayout layout;
  final DashboardInput input;

  /// Resolves the per-mode binding label for a control. Empty or `-` means
  /// unbound: the cell renders disabled and sends nothing.
  final String Function(ControlId control) bindingFor;

  /// Phone-held light/signal state for blink visuals. Null renders signal
  /// and hazard cells inert.
  final DashboardSendGate? gate;
  final PedalInput pedalInput;

  /// Pedals rendered in their slots; hidden pedal slots render nothing.
  final Set<PedalType> shownPedals;

  /// Selected lock-to-lock range in degrees for the wheel.
  final int degrees;
  final ValueChanged<double> onSteering;

  /// Whether the wheel animates back to zero on release.
  final bool springBack;

  /// Which key set the camera pad sends; the pad's center hold toggles it.
  final CameraPadMode cameraPadMode;
  final VoidCallback onCameraPadModeSwitch;
  final ValueChanged<ControlId>? onBindRequested;

  /// Which camera control shape the pad slot renders.
  final CameraControlType cameraControlType;

  /// Reports analog stick positions to the state stream.
  final ValueChanged<Offset>? onAnalog;

  /// When true, slot gestures select instead of activating: every slot is
  /// absorbed and a tap reports its rect through [onEditIntent].
  final bool editing;

  /// Fires with the tapped slot's rect while [editing]; null otherwise.
  final ValueChanged<CellRect>? onEditIntent;

  /// Wraps the tap-to-select tile of each slot while [editing], so the
  /// editor can add drag handling around it. Null keeps the plain tile.
  final Widget Function(
    BuildContext context,
    LayoutSlot slot,
    Widget child,
  )?
  editSlotWrapper;

  /// The global grid the layout slots address.
  static const int gridRows = 8;
  static const int gridCols = 15;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / gridCols;
        final cellH = constraints.maxHeight / gridRows;
        return Stack(
          children: [
            for (final slot in layout.slots)
              Positioned(
                left: (slot.rect.colStart - 1) * cellW,
                top: (slot.rect.rowStart - 1) * cellH,
                width: slot.rect.colSpan * cellW,
                height: slot.rect.rowSpan * cellH,
                child:
                    editing
                        ? _editingTile(context, slot, cellW, cellH)
                        : _buildSlot(slot, cellW, cellH),
              ),
          ],
        );
      },
    );
  }

  Widget _editingTile(
    BuildContext context,
    LayoutSlot slot,
    double cellW,
    double cellH,
  ) {
    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onEditIntent?.call(slot.rect),
      child: AbsorbPointer(child: _buildSlot(slot, cellW, cellH)),
    );
    return editSlotWrapper?.call(context, slot, tile) ?? tile;
  }

  Widget _buildSlot(LayoutSlot slot, double cellW, double cellH) {
    final rect = slot.rect;
    // Cells fill their slot rect, so the box follows the screen-derived cell
    // aspect (CON-001).
    final cellWidth = rect.colSpan * cellW;
    final cellHeight = rect.rowSpan * cellH;

    switch (slot.kind) {
      case SlotKind.wheel:
        // Square box: diameter equals the slot's pixel height, horizontally
        // centered with equal margins, flush with the slot's bottom edge.
        return Align(
          alignment: Alignment.bottomCenter,
          child: RotatableWheel(
            key: const ValueKey('wheel-slot'),
            degrees: degrees,
            onChanged: onSteering,
            size: rect.rowSpan * cellH,
            springBack: springBack,
          ),
        );
      case SlotKind.pedal:
        final pedal = slot.pedal;
        if (pedal == null || !shownPedals.contains(pedal)) {
          return const SizedBox.shrink();
        }
        // Fixed 8px inset inside each bar keeps a gap between adjacent slots.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: PedalBar(
            key: ValueKey('pedal-${pedal.name}'),
            pedal: pedal,
            width: null,
            pressure: pedalInput.pressureOf(pedal),
            onDrag: pedalInput.setPressure,
            onRelease: pedalInput.release,
          ),
        );
      case SlotKind.cameraPad:
        return CameraPad(
          mode: cameraPadMode,
          input: input,
          bindingFor: bindingFor,
          onModeSwitch: onCameraPadModeSwitch,
          onBindRequested: onBindRequested,
          controlType: cameraControlType,
          onAnalog: onAnalog,
        );
      case SlotKind.hole:
        return DashboardControl(
          key: ValueKey('hole-r${rect.rowStart}c${rect.colStart}'),
          label: '',
          control: null,
          input: input,
          mode: ControlMode.toggle,
          width: cellWidth,
          height: cellHeight,
          enabled: false,
        );
      case SlotKind.button:
      case SlotKind.gearUp:
      case SlotKind.gearDown:
        final control = slot.control!;
        return DashboardControl(
          key: ValueKey('dashboard-${control.name}'),
          label: DashboardPanel.gridLabel(control),
          control: control,
          input: input,
          mode: DashboardControl.modeFor(control),
          width: cellWidth,
          height: cellHeight,
          gate: gate,
          enabled: !DashboardSendGate.isUnbound(bindingFor(control)),
          onBindRequested: onBindRequested,
        );
    }
  }
}
