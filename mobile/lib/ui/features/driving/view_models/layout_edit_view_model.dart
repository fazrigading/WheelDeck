import 'package:flutter/foundation.dart';

import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/driving_layout.dart' as dl;

/// Working copy of a [dl.DrivingLayout] while the editor is open.
///
/// Wraps the committed layout, applies the pure edit primitives from
/// `driving_layout.dart`, and notifies through [ChangeNotifier] following
/// the driving view-model pattern. Every mutation is best-effort and never
/// throws: a refused edit only records its [lastRefusal] so the editor can
/// explain the failed drop.
///
/// `saveAs` keeps the named snapshot in memory; persistence lands with the
/// profile store (Phase 4), which also adds the developer-preset name check.
class LayoutEditViewModel extends ChangeNotifier {
  LayoutEditViewModel({required dl.DrivingLayout initialLayout})
    : _committed = initialLayout,
      _working = initialLayout;

  final dl.DrivingLayout _committed;
  dl.DrivingLayout _working;
  bool _editing = false;
  dl.CellRect? _selected;
  dl.EditRefusal? _lastRefusal;
  final Map<String, dl.DrivingLayout> _profiles = {};

  /// Whether an edit session is open.
  bool get editing => _editing;

  /// The tapped slot span, or null when nothing is selected.
  dl.CellRect? get selected => _selected;

  /// Why the last edit was refused, or null when it applied.
  dl.EditRefusal? get lastRefusal => _lastRefusal;

  /// Immutable snapshot of the working layout for the renderer.
  dl.DrivingLayout get workingLayout => dl.DrivingLayout(
    name: _working.name,
    slots: List.unmodifiable(_working.slots),
  );

  /// In-memory named snapshots saved through [saveAs].
  Map<String, dl.DrivingLayout> get savedProfiles =>
      Map.unmodifiable(_profiles);

  /// Valid drop targets for a [rowSpan] x [colSpan] slot in the working
  /// layout. Never throws: returns empty on bad spans.
  Set<dl.CellRect> freeSpansFor(int rowSpan, int colSpan) {
    try {
      return dl.freeSpans(_working, rowSpan, colSpan);
    } catch (_) {
      return const {};
    }
  }

  /// Opens an edit session on a fresh copy of the committed layout.
  void beginEdit() {
    try {
      _working = _committed;
      _editing = true;
      _selected = null;
      _lastRefusal = null;
    } catch (_) {}
    notifyListeners();
  }

  /// Discards the working layout and closes the session.
  void cancelEdit() {
    try {
      _working = _committed;
      _editing = false;
      _selected = null;
      _lastRefusal = null;
    } catch (_) {}
    notifyListeners();
  }

  /// Selects the tapped slot span. Ignored outside an edit session.
  void select(dl.CellRect? rect) {
    try {
      if (!_editing) return;
      _selected = rect;
    } catch (_) {}
    notifyListeners();
  }

  /// Moves the slot at [from] to [to] in the working layout.
  void move(dl.CellRect from, dl.CellRect to) {
    _apply(dl.applyMove(_working, from, to));
  }

  /// Adds [control] as a button slot at [at] in the working layout.
  void addControl(dl.CellRect at, ControlId control) {
    _apply(dl.addControl(_working, at, control));
  }

  /// Removes the slot at [at] from the working layout.
  void remove(dl.CellRect at) {
    _apply(dl.removeSlot(_working, at));
  }

  /// Saves the working layout under [name]. Returns false for a blank name;
  /// otherwise stores the snapshot and returns true.
  bool saveAs(String name) {
    try {
      if (name.trim().isEmpty) return false;
      _profiles[name.trim()] = _working;
      _lastRefusal = null;
    } catch (_) {
      return false;
    }
    notifyListeners();
    return true;
  }

  void _apply(dl.LayoutEditResult result) {
    try {
      switch (result) {
        case dl.EditApplied(:final layout):
          _working = layout;
          _lastRefusal = null;
        case dl.EditRefused(:final reason):
          _lastRefusal = reason;
      }
    } catch (_) {}
    notifyListeners();
  }
}
