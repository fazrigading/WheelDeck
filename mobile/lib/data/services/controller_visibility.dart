import 'package:shared_preferences/shared_preferences.dart';

/// Which optional inputs are shown on the driving screen. Steering Wheel,
/// Accelerator, and Brake are always shown.
class ControllerVisibility {
  const ControllerVisibility({
    required this.showClutch,
    required this.showDashboard,
  });

  final bool showClutch;
  final bool showDashboard;

  static const String clutchKey = 'wheeldeck.show_clutch';
  static const String dashboardKey = 'wheeldeck.show_dashboard';
  static const String legacyKey = 'wheeldeck.controller_type';

  /// Legacy 5-way values mapped to visibility pairs.
  static const Map<String, (bool, bool)> _legacy = {
    'steeringOnly': (false, false),
    'steering3Pedals': (true, false),
    'steering2Pedals': (false, false),
    'steeringDashboard': (false, true),
    'full': (true, true),
  };

  static const ControllerVisibility fallback =
      ControllerVisibility(showClutch: false, showDashboard: true);

  static Future<ControllerVisibility> load() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(legacyKey);
    if (legacy != null) {
      final pair = _legacy[legacy] ?? (false, true);
      final migrated = ControllerVisibility(
        showClutch: pair.$1,
        showDashboard: pair.$2,
      );
      await migrated.save();
      await prefs.remove(legacyKey);
      return migrated;
    }
    final clutch = prefs.getBool(clutchKey);
    final dashboard = prefs.getBool(dashboardKey);
    if (clutch == null && dashboard == null) return fallback;
    return ControllerVisibility(
      showClutch: clutch ?? fallback.showClutch,
      showDashboard: dashboard ?? fallback.showDashboard,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(clutchKey, showClutch);
    await prefs.setBool(dashboardKey, showDashboard);
  }
}
