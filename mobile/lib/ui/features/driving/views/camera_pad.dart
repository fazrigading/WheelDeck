import 'package:flutter/material.dart';

import '../../../../data/services/camera_control_type.dart';
import '../../../../data/services/camera_pad_mode.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import 'dashboard_panel.dart';

/// The rotatable block C camera pad: a 3x3 of direction cells around a
/// center cell whose three-second hold switches the pad's key set. In
/// numpad mode the pad sends the numpad block; in arrow mode the arrow
/// keys, with the diagonals disabled — they carry no wire identifiers
/// (REQ-017).
///
/// The pad dispatches on [controlType]: `dpad` renders below, while the
/// Simple and Analog shapes land with their own issues.
class CameraPad extends StatelessWidget {
  const CameraPad({
    super.key,
    required this.mode,
    required this.input,
    required this.bindingFor,
    required this.onModeSwitch,
    this.onBindRequested,
    this.controlType = CameraControlType.dpad,
  });

  final CameraPadMode mode;
  final DashboardInput input;
  final String Function(ControlId control) bindingFor;

  /// Called when the center hold completes; the driving view model owns
  /// the mode and persists the switch.
  final VoidCallback onModeSwitch;
  final ValueChanged<ControlId>? onBindRequested;

  /// Which camera control shape renders; Simple and Analog branches land
  /// with their own issues.
  final CameraControlType controlType;

  static const Duration _holdDuration = Duration(seconds: 3);

  /// The glyph each of the nine cells renders, row-major.
  static const List<String> _glyphs = [
    '↖',
    '↑',
    '↗',
    '←',
    '',
    '→',
    '↙',
    '↓',
    '↘',
  ];

  /// The control a direction cell sends in [mode], or null where the cell
  /// is inert: the diagonals in arrow mode, and the center's press in
  /// arrow mode (recenter is a numpad-set key).
  ControlId? _controlAt(int row, int col) {
    final center = row == 1 && col == 1;
    if (center) {
      return mode == CameraPadMode.numpad ? ControlId.cameraPadRecenter : null;
    }
    final diagonal = (row == 0 || row == 2) && (col == 0 || col == 2);
    if (mode == CameraPadMode.arrow && diagonal) return null;
    return switch (mode) {
      CameraPadMode.numpad => switch ((row, col)) {
        (0, 0) => ControlId.cameraPadUpLeft,
        (0, 1) => ControlId.cameraPadUp,
        (0, 2) => ControlId.cameraPadUpRight,
        (1, 0) => ControlId.cameraPadLeft,
        (1, 2) => ControlId.cameraPadRight,
        (2, 0) => ControlId.cameraPadDownLeft,
        (2, 1) => ControlId.cameraPadDown,
        (2, 2) => ControlId.cameraPadDownRight,
        _ => null,
      },
      CameraPadMode.arrow => switch ((row, col)) {
        (0, 1) => ControlId.cameraPadArrowUp,
        (1, 0) => ControlId.cameraPadArrowLeft,
        (1, 2) => ControlId.cameraPadArrowRight,
        (2, 1) => ControlId.cameraPadArrowDown,
        _ => null,
      },
    };
  }

  Widget _cell(int row, int col, Size cellSize) {
    final center = row == 1 && col == 1;
    final control = _controlAt(row, col);
    final key = ValueKey(
      center
          ? 'camera-pad-center'
          : control != null
          ? 'camera-pad-${control.name}'
          : 'camera-pad-diagonal',
    );

    return Positioned(
      left: col * cellSize.width,
      top: row * cellSize.height,
      width: cellSize.width,
      height: cellSize.height,
      child: DashboardControl(
        key: key,
        label: center
            ? (mode == CameraPadMode.numpad ? 'NUM' : 'ARR')
            : _glyphs[row * 3 + col],
        control: control,
        input: input,
        mode: center ? ControlMode.tapOrHold : ControlMode.momentary,
        holdDuration: _holdDuration,
        onHoldCompleted: center ? onModeSwitch : null,
        width: cellSize.width,
        height: cellSize.height,
        // The center is always live — it is the hold surface for the mode
        // switch — while inert direction cells (arrow-mode diagonals)
        // render disabled like holes. Unbound sends are suppressed by the
        // send gate at the view model level.
        enabled:
            center ||
            (control != null &&
                !DashboardSendGate.isUnbound(bindingFor(control))),
        onBindRequested: onBindRequested,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (controlType) {
      CameraControlType.dpad => LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = Size(
            constraints.maxWidth / 3,
            constraints.maxHeight / 3,
          );
          return Stack(
            children: [
              for (var row = 0; row < 3; row++)
                for (var col = 0; col < 3; col++) _cell(row, col, cellSize),
            ],
          );
        },
      ),
      // Analog shape lands with its own issue.
      CameraControlType.analog => const SizedBox.shrink(),
      CameraControlType.simple => LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = Size(
            constraints.maxWidth / 3,
            constraints.maxHeight,
          );
          return Stack(
            children: [
              for (var col = 0; col < 3; col++) _simpleCell(col, cellSize),
            ],
          );
        },
      ),
    };
  }

  /// Simple type (REQ-013): three full-height buttons — Look Left Window
  /// (`Numpad/`), Recenter (`Numpad5`), Look Right Window (`Numpad*`).
  /// The desktop resolves the keys from the control identifiers.
  Widget _simpleCell(int col, Size cellSize) {
    final control = switch (col) {
      0 => ControlId.cameraSimpleLeft,
      1 => ControlId.cameraPadRecenter,
      _ => ControlId.cameraSimpleRight,
    };
    final label = switch (col) {
      0 => '◀ WIN',
      1 => 'REC',
      _ => 'WIN ▶',
    };
    return Positioned(
      left: col * cellSize.width,
      top: 0,
      width: cellSize.width,
      height: cellSize.height,
      child: DashboardControl(
        key: ValueKey('camera-simple-${control.name}'),
        label: label,
        control: control,
        input: input,
        mode: ControlMode.momentary,
        width: cellSize.width,
        height: cellSize.height,
        enabled: !DashboardSendGate.isUnbound(bindingFor(control)),
        onBindRequested: onBindRequested,
      ),
    );
  }
}
