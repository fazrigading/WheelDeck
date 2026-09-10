import 'package:shared_preferences/shared_preferences.dart';

import 'pedal_input.dart';

/// Pedal arrangement & visibility.
enum PedalLayout {
  /// a) Acc R, Brake R, Clutch L  — 3 pedals, clutch left, brake mid, acc right
  layoutA('layoutA', 'A — Acc(R) Brake(R) Clutch(L)', [PedalType.clutch, PedalType.brake, PedalType.accelerator]),
  /// b) Acc R, Brake L, Clutch L — 3 pedals, brake left, clutch mid
  layoutB('layoutB', 'B — Acc(R) Brake(L) Clutch(L)', [PedalType.brake, PedalType.clutch, PedalType.accelerator]),
  /// c) A without clutch — 2 pedals
  layoutC('layoutC', 'C — Acc(R) Brake(R) no clutch', [PedalType.brake, PedalType.accelerator]),
  /// d) B without clutch — 2 pedals
  layoutD('layoutD', 'D — Acc(R) Brake(L) no clutch', [PedalType.brake, PedalType.accelerator]);

  const PedalLayout(this.wireValue, this.label, this.order);
  final String wireValue;
  final String label;
  final List<PedalType> order;

  bool get hasClutch => order.contains(PedalType.clutch);

  static const String prefsKey = 'wheeldeck.pedal_layout';
  static const PedalLayout fallback = layoutA;

  static PedalLayout fromWireValue(String? v) =>
      PedalLayout.values.firstWhere((e) => e.wireValue == v, orElse: () => fallback);

  static Future<PedalLayout> load() async {
    final prefs = await SharedPreferences.getInstance();
    return fromWireValue(prefs.getString(prefsKey));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, wireValue);
  }
}
