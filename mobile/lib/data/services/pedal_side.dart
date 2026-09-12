import 'package:shared_preferences/shared_preferences.dart';

import 'pedal_input.dart';

/// Left or Right screen placement for a pedal.
enum PedalSide {
  left('left'),
  right('right');

  const PedalSide(this.wireValue);
  final String wireValue;

  static PedalSide fromWireValue(String? v) => PedalSide.values
      .firstWhere((s) => s.wireValue == v, orElse: () => right);
}

/// Per-pedal screen placement, replacing the fixed PedalLayout variants.
class PedalSides {
  PedalSides(Map<PedalType, PedalSide> sides)
      : _sides = {..._defaults, ...sides};

  static const Map<PedalType, PedalSide> _defaults = {
    PedalType.accelerator: PedalSide.right,
    PedalType.brake: PedalSide.right,
    PedalType.clutch: PedalSide.left,
  };

  static const String keyPrefix = 'wheeldeck.pedal_side.';
  static const String legacyKey = 'wheeldeck.pedal_layout';

  /// Legacy layout variants mapped to per-pedal sides. layoutA mirrors defaults.
  static const Map<String, Map<PedalType, PedalSide>> _legacy = {
    'layoutA': {
      PedalType.accelerator: PedalSide.right,
      PedalType.brake: PedalSide.right,
      PedalType.clutch: PedalSide.left,
    },
    'layoutB': {
      PedalType.accelerator: PedalSide.right,
      PedalType.brake: PedalSide.left,
      PedalType.clutch: PedalSide.left,
    },
    'layoutC': {
      PedalType.accelerator: PedalSide.right,
      PedalType.brake: PedalSide.right,
    },
    'layoutD': {
      PedalType.accelerator: PedalSide.right,
      PedalType.brake: PedalSide.left,
    },
  };

  final Map<PedalType, PedalSide> _sides;

  PedalSide sideOf(PedalType pedal) => _sides[pedal] ?? _defaults[pedal]!;

  /// Complete sides map. Callers needing a mutable copy start here.
  Map<PedalType, PedalSide> asMap() => Map.of(_sides);

  static PedalSides defaults() => PedalSides({});

  PedalSides copyWithSide(PedalType pedal, PedalSide side) =>
      PedalSides({..._sides, pedal: side});

  static Future<PedalSides> load() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(legacyKey);
    if (legacy != null) {
      final migrated = PedalSides(_legacy[legacy] ?? {});
      await migrated.save();
      await prefs.remove(legacyKey);
      return migrated;
    }
    final sides = <PedalType, PedalSide>{};
    for (final pedal in PedalType.values) {
      final raw = prefs.getString('$keyPrefix${pedal.name}');
      if (raw != null) sides[pedal] = PedalSide.fromWireValue(raw);
    }
    return PedalSides(sides);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    for (final pedal in PedalType.values) {
      await prefs.setString(
          '$keyPrefix${pedal.name}', sideOf(pedal).wireValue);
    }
  }
}
