import 'package:flutter/material.dart';

import '../../../../data/services/camera_pad_mode.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import '../../../../data/services/driving_layout.dart';
import '../../../../data/services/pedal_input.dart';
import '../view_models/layout_edit_view_model.dart';
import 'block_grid.dart';

/// Edit-mode surface for the driving grid: drag occupied slots between
/// cells, with valid drop targets highlighted and refusals flashed.
///
/// The grid itself never rebuilds mid-drag (PERF-001): the dragged snapshot
/// renders in the overlay through [Draggable.feedback], hover highlights only
/// rebuild their own [DragTarget], and the edit view model is notified once
/// on drop. Drops map the pointer to whole cells, so free-form pixel
/// placement is impossible by construction (REQ-004).
class LayoutEditor extends StatefulWidget {
  const LayoutEditor({
    super.key,
    required this.edit,
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
  });

  final LayoutEditViewModel edit;
  final DashboardInput input;
  final String Function(ControlId control) bindingFor;
  final DashboardSendGate? gate;
  final PedalInput pedalInput;
  final Set<PedalType> shownPedals;
  final int degrees;
  final ValueChanged<double> onSteering;
  final bool springBack;
  final CameraPadMode cameraPadMode;
  final VoidCallback onCameraPadModeSwitch;
  final ValueChanged<ControlId>? onBindRequested;

  @override
  State<LayoutEditor> createState() => _LayoutEditorState();
}

class _LayoutEditorState extends State<LayoutEditor> {
  final _gridKey = GlobalKey();

  /// Span of the in-flight drag, or null while not dragging.
  CellRect? _dragFrom;

  /// Free spans for [_dragFrom]'s shape, snapshotted at drag start.
  Set<CellRect> _dragTargets = const {};

  /// Refused drop flashing red, cleared shortly after.
  CellRect? _flash;

  double _cellW = 0;
  double _cellH = 0;

  LayoutEditViewModel get _edit => widget.edit;

  void _beginDrag(CellRect from) {
    setState(() {
      _dragFrom = from;
      _dragTargets = _edit.freeSpansFor(from.rowSpan, from.colSpan);
      _flash = null;
    });
  }

  void _endDrag() {
    setState(() {
      _dragFrom = null;
      _dragTargets = const {};
    });
  }

  /// Drops outside every target: map the pointer to whole cells and move.
  /// The primitive refuses overlaps and out-of-bounds spans alike.
  void _dropAt(Offset globalOffset) {
    final from = _dragFrom;
    if (from == null) return;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _cellW <= 0 || _cellH <= 0) return;
    final local = box.globalToLocal(globalOffset);
    final to = CellRect(
      rowStart: (local.dy / _cellH).floor() + 1,
      colStart: (local.dx / _cellW).floor() + 1,
      rowSpan: from.rowSpan,
      colSpan: from.colSpan,
    );
    _edit.move(from, to);
    if (_edit.lastRefusal != null && _inGrid(to)) {
      setState(() => _flash = to);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _flash = null);
      });
    }
  }

  bool _inGrid(CellRect rect) =>
      rect.rowStart >= 1 &&
      rect.colStart >= 1 &&
      rect.rowStart + rect.rowSpan - 1 <= DrivingLayout.gridRows &&
      rect.colStart + rect.colSpan - 1 <= DrivingLayout.gridCols;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _cellW = constraints.maxWidth / DrivingLayout.gridCols;
        _cellH = constraints.maxHeight / DrivingLayout.gridRows;
        return ListenableBuilder(
          listenable: _edit,
          builder:
              (context, _) => Stack(
                children: [
                  Positioned.fill(
                    child: BlockGrid(
                      key: _gridKey,
                      layout: _edit.workingLayout,
                      input: widget.input,
                      bindingFor: widget.bindingFor,
                      gate: widget.gate,
                      pedalInput: widget.pedalInput,
                      shownPedals: widget.shownPedals,
                      degrees: widget.degrees,
                      onSteering: widget.onSteering,
                      springBack: widget.springBack,
                      cameraPadMode: widget.cameraPadMode,
                      onCameraPadModeSwitch: widget.onCameraPadModeSwitch,
                      onBindRequested: widget.onBindRequested,
                      editing: true,
                      onEditIntent: _edit.select,
                      editSlotWrapper:
                          (context, slot, child) => _draggableSlot(slot, child),
                    ),
                  ),
                  for (final target in _dragTargets)
                    Positioned(
                      left: (target.colStart - 1) * _cellW,
                      top: (target.rowStart - 1) * _cellH,
                      width: target.colSpan * _cellW,
                      height: target.rowSpan * _cellH,
                      child: DragTarget<CellRect>(
                        onWillAcceptWithDetails: (_) => true,
                        onAcceptWithDetails:
                            (details) => _edit.move(details.data, target),
                        builder:
                            (context, candidate, _) => Container(
                              decoration: BoxDecoration(
                                color:
                                    candidate.isNotEmpty
                                        ? Colors.green.withValues(alpha: 0.45)
                                        : Colors.green.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                            ),
                      ),
                    ),
                  if (_flash != null)
                    Positioned(
                      left: (_flash!.colStart - 1) * _cellW,
                      top: (_flash!.rowStart - 1) * _cellH,
                      width: _flash!.colSpan * _cellW,
                      height: _flash!.rowSpan * _cellH,
                      child: Container(
                        key: const ValueKey('refusal-flash'),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.45),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
        );
      },
    );
  }

  Widget _draggableSlot(LayoutSlot slot, Widget child) {
    return Draggable<CellRect>(
      data: slot.rect,
      feedback: SizedBox(
        width: slot.rect.colSpan * _cellW,
        height: slot.rect.rowSpan * _cellH,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.55),
            border: Border.all(color: Colors.blue, width: 2),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      onDragStarted: () => _beginDrag(slot.rect),
      onDragCompleted: _endDrag,
      onDraggableCanceled: (_, offset) {
        _dropAt(offset);
        _endDrag();
      },
      child: child,
    );
  }
}
