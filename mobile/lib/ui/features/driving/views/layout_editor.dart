import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/services/camera_pad_mode.dart';
import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import '../../../../data/services/driving_layout.dart';
import '../../../../data/services/pedal_input.dart';
import '../view_models/layout_edit_view_model.dart';
import 'block_grid.dart';
import 'dashboard_panel.dart';

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
    this.addableControls = const [],
    this.developerPresetNames = const {'Sequential'},
    this.onSaveProfile,
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

  /// Controls offered by the add picker: every id with a binding resolved
  /// in either input mapping mode (TASK-016).
  final List<ControlId> addableControls;

  /// Developer preset names; saving under one is refused (REQ-007).
  final Set<String> developerPresetNames;

  /// Persists a saved profile; null keeps the edit session's in-memory
  /// snapshot. False reports a save failure inline.
  final Future<bool> Function(String name, DrivingLayout layout)?
  onSaveProfile;

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
  Timer? _flashTimer;

  /// Long-lived save-name controller: dialogs outlive a per-open controller
  /// through their pop animation.
  final _saveController = TextEditingController();

  /// Control chosen from the picker awaiting a target cell, or null.
  ControlId? _placing;

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
      _flashRed(to);
    }
  }

  void _flashRed(CellRect at) {
    _flashTimer?.cancel();
    setState(() => _flash = at);
    _flashTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _saveController.dispose();
    super.dispose();
  }

  bool _inGrid(CellRect rect) =>
      rect.rowStart >= 1 &&
      rect.colStart >= 1 &&
      rect.rowStart + rect.rowSpan - 1 <= DrivingLayout.gridRows &&
      rect.colStart + rect.colSpan - 1 <= DrivingLayout.gridCols;

  /// Places the picked control into the tapped 1x1 cell. Occupied targets
  /// are refused with the same red flash as a refused move.
  void _placeAt(Offset globalOffset) {
    final placing = _placing;
    if (placing == null) return;
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _cellW <= 0 || _cellH <= 0) return;
    final local = box.globalToLocal(globalOffset);
    final at = CellRect(
      rowStart: (local.dy / _cellH).floor() + 1,
      colStart: (local.dx / _cellW).floor() + 1,
      rowSpan: 1,
      colSpan: 1,
    );
    _edit.addControl(at, placing);
    if (_edit.lastRefusal != null) {
      if (_inGrid(at)) _flashRed(at);
    } else {
      setState(() => _placing = null);
    }
  }

  /// Add picker: every bound control; choosing one arms placing mode.
  Future<void> _openAddPicker() async {
    final picked = await showDialog<ControlId>(
      context: context,
      builder:
          (context) => SimpleDialog(
            key: const ValueKey('add-picker'),
            title: const Text('Add control'),
            children: [
              for (final control in widget.addableControls)
                SimpleDialogOption(
                  key: ValueKey('add-control-${control.name}'),
                  onPressed: () => Navigator.of(context).pop(control),
                  child: Text(DashboardPanel.gridLabel(control)),
                ),
            ],
          ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _placing = picked;
      _flash = null;
    });
  }

  /// Removes the selected slot; structural slots refuse at the primitive.
  void _removeSelected() {
    final selected = _edit.selected;
    if (selected == null) return;
    _edit.remove(selected);
    if (_edit.lastRefusal != null) {
      _flashRed(selected);
    } else {
      _edit.select(null);
    }
  }

  /// Save action: prompts for a profile name; developer preset names refuse.
  Future<void> _openSaveDialog() async {
    _saveController.clear();
    await showDialog<void>(
      context: context,
      builder:
          (context) => _SaveDialog(
            controller: _saveController,
            takenNames: widget.developerPresetNames,
            onSave: (name) async {
              final hook = widget.onSaveProfile;
              if (hook != null) {
                return hook(name, _edit.workingLayout);
              }
              return _edit.saveAs(name);
            },
          ),
    );
  }

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
                  if (_placing != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown:
                            (details) =>
                                _placeAt(details.globalPosition),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(child: _toolbar()),
                  ),
                ],
              ),
        );
      },
    );
  }

  /// Add/remove/save toolbar. While placing, it shows the picked control
  /// with a cancel action instead.
  Widget _toolbar() {
    final placing = _placing;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child:
            placing != null
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Placing ${DashboardPanel.gridLabel(placing)} — tap a cell',
                    ),
                    IconButton(
                      key: const ValueKey('placing-cancel'),
                      tooltip: 'Cancel placing',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _placing = null),
                    ),
                  ],
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('editor-add'),
                      onPressed: _openAddPicker,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('editor-remove'),
                      onPressed:
                          _edit.selected == null ? null : _removeSelected,
                      icon: const Icon(Icons.remove),
                      label: const Text('Remove'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('editor-save'),
                      onPressed: _openSaveDialog,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
      ),
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

/// Save dialog: names the working layout. Blank names and developer preset
/// names are refused inline; the dialog only closes on a real save.
class _SaveDialog extends StatefulWidget {
  const _SaveDialog({
    required this.controller,
    required this.takenNames,
    required this.onSave,
  });

  final TextEditingController controller;
  final Set<String> takenNames;
  final Future<bool> Function(String name) onSave;

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  String? _error;

  void _submit() async {
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a profile name.');
      return;
    }
    if (widget.takenNames.contains(name)) {
      setState(() => _error = 'That name belongs to a developer preset.');
      return;
    }
    if (!await widget.onSave(name)) {
      if (mounted) setState(() => _error = 'Save failed. Try again.');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('save-dialog'),
      title: const Text('Save layout'),
      content: TextField(
        key: const ValueKey('save-name-field'),
        controller: widget.controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Profile name',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('save-confirm'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
