import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_input.dart';
import 'driving_layout.dart';
import 'pedal_input.dart';

/// A named dashboard layout: either a developer-shipped preset or a user
/// profile. Profiles record layout only; bindings, pedal sides, and
/// visibility stay in their existing global stores (REQ-008).
class LayoutProfile {
  const LayoutProfile({
    required this.name,
    required this.layout,
    this.isDeveloperPreset = false,
  });

  final String name;
  final DrivingLayout layout;
  final bool isDeveloperPreset;

  Map<String, Object?> toJson() => {
    'name': name,
    'preset': isDeveloperPreset,
    'slots': [
      for (final slot in layout.slots)
        {
          'rect': [
            slot.rect.rowStart,
            slot.rect.colStart,
            slot.rect.rowSpan,
            slot.rect.colSpan,
          ],
          'kind': slot.kind.name,
          if (slot.control != null) 'control': slot.control!.wireValue,
          if (slot.pedal != null) 'pedal': slot.pedal!.name,
        },
    ],
  };

  /// Null when [json] is corrupt. Unknown control wire values become holes
  /// so a profile saved by an older build still loads after an enum change.
  /// Unknown kinds and pedals degrade the same way.
  static LayoutProfile? fromJson(Map<String, Object?> json) {
    try {
      final name = json['name'];
      final slots = json['slots'];
      if (name is! String || slots is! List) return null;
      return LayoutProfile(
        name: name,
        layout: DrivingLayout(name: name, slots: [
          for (final entry in slots)
            if (entry is Map<String, Object?>)
              _slotFromJson(entry)
            else
              const LayoutSlot(
                rect: CellRect(
                  rowStart: 1,
                  colStart: 1,
                  rowSpan: 1,
                  colSpan: 1,
                ),
                kind: SlotKind.hole,
              ),
        ]),
      );
    } catch (_) {
      return null;
    }
  }

  static LayoutSlot _slotFromJson(Map<String, Object?> json) {
    const hole = LayoutSlot(
      rect: CellRect(rowStart: 1, colStart: 1, rowSpan: 1, colSpan: 1),
      kind: SlotKind.hole,
    );
    try {
      final rect = json['rect'];
      if (rect is! List || rect.length != 4) return hole;
      final dims = [for (final v in rect) (v as num).toInt()];
      if (dims.any((v) => v < 1)) return hole;
      final parsed = CellRect(
        rowStart: dims[0],
        colStart: dims[1],
        rowSpan: dims[2],
        colSpan: dims[3],
      );
      final kind = SlotKind.values.asNameMap()[json['kind']];
      final byWire = {for (final c in ControlId.values) c.wireValue: c};
      final control = json['control'] is String
          ? byWire[json['control']]
          : null;
      final pedal = json['pedal'] is String
          ? PedalType.values.asNameMap()[json['pedal']]
          : null;
      switch (kind) {
        case SlotKind.button:
        case SlotKind.gearUp:
        case SlotKind.gearDown:
          if (json['control'] is! String || control == null) {
            return LayoutSlot(rect: parsed, kind: SlotKind.hole);
          }
          return LayoutSlot(
            rect: parsed,
            kind: kind!,
            control: control,
          );
        case SlotKind.pedal:
          if (pedal == null) {
            return LayoutSlot(rect: parsed, kind: SlotKind.hole);
          }
          return LayoutSlot(rect: parsed, kind: kind!, pedal: pedal);
        case SlotKind.wheel:
        case SlotKind.cameraPad:
        case SlotKind.hole:
          return LayoutSlot(rect: parsed, kind: kind ?? SlotKind.hole);
        case null:
          return LayoutSlot(rect: parsed, kind: SlotKind.hole);
      }
    } catch (_) {
      return hole;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutProfile &&
          name == other.name &&
          isDeveloperPreset == other.isDeveloperPreset &&
          layout.slots.length == other.layout.slots.length &&
          [
            for (var i = 0; i < layout.slots.length; i++)
              layout.slots[i] == other.layout.slots[i],
          ].every((same) => same);

  @override
  int get hashCode => Object.hash(name, isDeveloperPreset, layout.slots.length);

  @override
  String toString() => 'LayoutProfile($name)';
}

/// Persists user profiles as a JSON string list; developer presets are
/// compiled in and read-only. A persisted entry naming a developer preset is
/// ignored on load, enforcing REQ-007 at the storage boundary.
class LayoutProfileStore {
  static const String prefsKey = 'wheeldeck.layout_profiles';
  static const String activePrefsKey = 'wheeldeck.layout_active_profile';
  static const String defaultProfileName = 'Sequential';

  /// Developer presets compiled into the app. Phase 6 adds the Automatic
  /// and H-Shifter presets here.
  static List<LayoutProfile> get developerPresets => [
    LayoutProfile(
      name: defaultProfileName,
      layout: DrivingLayout.sequential(),
      isDeveloperPreset: true,
    ),
  ];

  static Set<String> get developerPresetNames =>
      developerPresets.map((p) => p.name).toSet();

  /// Persisted user profiles plus the developer presets.
  static Future<List<LayoutProfile>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(prefsKey) ?? const [];
      final presetNames = developerPresetNames;
      final users = <LayoutProfile>[];
      for (final raw in stored) {
        try {
          final json = jsonDecode(raw);
          if (json is! Map<String, Object?>) continue;
          final profile = LayoutProfile.fromJson(json);
          if (profile == null) continue;
          // Read-only boundary: persisted entries may not shadow presets.
          if (presetNames.contains(profile.name)) continue;
          users.add(profile);
        } catch (_) {}
      }
      return [...developerPresets, ...users];
    } catch (_) {
      return developerPresets;
    }
  }

  /// Saves a user profile, replacing any same-named entry. Returns false
  /// for blank names and developer preset names, which are read-only.
  static Future<bool> saveProfile(LayoutProfile profile) async {
    final name = profile.name.trim();
    if (name.isEmpty || developerPresetNames.contains(name)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(prefsKey) ?? const [];
      final kept = <String>[];
      for (final raw in stored) {
        try {
          final json = jsonDecode(raw);
          if (json is Map<String, Object?> &&
              LayoutProfile.fromJson(json)?.name == name) {
            continue;
          }
        } catch (_) {}
        kept.add(raw);
      }
      kept.add(
        jsonEncode(
          LayoutProfile(
            name: name,
            layout: profile.layout,
          ).toJson(),
        ),
      );
      final ok = await prefs.setStringList(prefsKey, kept);
      return ok;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteProfile(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(prefsKey) ?? const [];
      final kept = <String>[];
      for (final raw in stored) {
        try {
          final json = jsonDecode(raw);
          if (json is Map<String, Object?> &&
              LayoutProfile.fromJson(json)?.name == name) {
            continue;
          }
        } catch (_) {}
        kept.add(raw);
      }
      await prefs.setStringList(prefsKey, kept);
    } catch (_) {}
  }

  static Future<String> loadActiveName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(activePrefsKey);
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return defaultProfileName;
  }

  static Future<void> saveActiveName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(activePrefsKey, name);
    } catch (_) {}
  }

  /// Layout for [name]: user profile, developer preset, or the Sequential
  /// fallback. Never throws.
  static Future<DrivingLayout> layoutFor(String name) async {
    try {
      final profiles = await loadAll();
      for (final profile in profiles) {
        if (profile.name == name) return profile.layout;
      }
    } catch (_) {}
    return DrivingLayout.sequential();
  }
}
