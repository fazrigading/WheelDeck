import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_input.dart';

/// Which extra dashboard controls appear in the grid. The core set (lights,
/// signals-free essentials) is always shown; these extras toggle in Settings.
///
/// Defaults: gears + engine brake ON, everything else OFF (REQ-009).
class DashboardVisibility {
  const DashboardVisibility(this.visibleExtras);

  /// Extras with a Settings toggle. Never overlaps the core grid set.
  static const List<ControlId> toggleable = [
    ControlId.gearUp,
    ControlId.gearDown,
    ControlId.engineBrake,
    ControlId.airHorn,
    ControlId.differentialLock,
    ControlId.retarderIncrease,
    ControlId.retarderDecrease,
    ControlId.quickInfo,
    ControlId.mirrorToggle,
    ControlId.hudWidgets,
    ControlId.vehicleAdjustment,
    ControlId.navigationZoomOut,
    ControlId.widgetOptions,
    ControlId.services,
    ControlId.quickSave,
    ControlId.quickLoad,
    ControlId.screenshot,
    ControlId.garageManager,
    ControlId.audioPlayer,
    // Comfort and chat batch (TASK-049): all ten are plain momentary
    // buttons that make sense in a gyro grid, so they are toggleable. The
    // camera and menu controls of the block E batch are not (REQ-011).
    ControlId.driverWindowUp,
    ControlId.driverWindowDown,
    ControlId.passengerWindowUp,
    ControlId.passengerWindowDown,
    ControlId.navigationZoomIn,
    ControlId.overlayActivation,
    ControlId.chatActivation,
    ControlId.quickReplies,
    ControlId.nameTags,
    ControlId.pushToTalk,
  ];

  static const Set<ControlId> defaults = {
    ControlId.gearUp,
    ControlId.gearDown,
    ControlId.engineBrake,
  };

  static const String prefsKey = 'wheeldeck.dashboard_extras';

  final Set<ControlId> visibleExtras;

  bool isVisible(ControlId control) => visibleExtras.contains(control);

  DashboardVisibility toggled(ControlId control) {
    final next = Set<ControlId>.of(visibleExtras);
    if (!next.remove(control)) next.add(control);
    return DashboardVisibility(next);
  }

  static Future<DashboardVisibility> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(prefsKey);
    if (stored == null) return const DashboardVisibility(defaults);
    final byWire = {for (final c in ControlId.values) c.wireValue: c};
    return DashboardVisibility({
      for (final wire in stored)
        if (byWire[wire] != null) byWire[wire]!,
    });
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      prefsKey,
      [for (final c in visibleExtras) c.wireValue],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardVisibility &&
      visibleExtras.length == other.visibleExtras.length &&
      visibleExtras.containsAll(other.visibleExtras);

  @override
  int get hashCode {
    final sorted = visibleExtras.map((c) => c.index).toList()..sort();
    return Object.hashAll(sorted);
  }

  @override
  String toString() => 'DashboardVisibility($visibleExtras)';
}
