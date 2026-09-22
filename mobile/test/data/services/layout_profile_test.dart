import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/driving_layout.dart';
import 'package:wheeldeck/data/services/layout_profile.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  LayoutProfile fixture(String name) => LayoutProfile(
    name: name,
    layout: const DrivingLayout(
      name: 'fixture',
      slots: [
        LayoutSlot(
          rect: CellRect(rowStart: 1, colStart: 1, rowSpan: 1, colSpan: 1),
          kind: SlotKind.button,
          control: ControlId.horn,
        ),
        LayoutSlot(
          rect: CellRect(rowStart: 5, colStart: 12, rowSpan: 4, colSpan: 2),
          kind: SlotKind.pedal,
          pedal: PedalType.brake,
        ),
        LayoutSlot(
          rect: CellRect(rowStart: 5, colStart: 6, rowSpan: 2, colSpan: 2),
          kind: SlotKind.wheel,
        ),
      ],
    ),
  );

  group('TASK-026 layout profiles', () {
    test('TEST-006 a saved profile round-trips to an identical layout', () async {
      expect(await LayoutProfileStore.saveProfile(fixture('Mine')), isTrue);

      final profiles = await LayoutProfileStore.loadAll();
      final mine = profiles.firstWhere((p) => p.name == 'Mine');
      expect(mine.isDeveloperPreset, isFalse);
      expect(mine, fixture('Mine'));
    });

    test('TEST-007 an unknown control wire value loads as a hole', () async {
      final json = fixture('Old').toJson();
      final slots = json['slots'] as List;
      (slots.first as Map<String, Object?>)['control'] = 'no_such_control';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(LayoutProfileStore.prefsKey, [
        jsonEncode(json),
      ]);

      final profiles = await LayoutProfileStore.loadAll();
      final old = profiles.firstWhere((p) => p.name == 'Old');
      expect(old.layout.slots.first.kind, SlotKind.hole);
      expect(old.layout.slots.first.control, isNull);
      expect(old.layout.slots.length, 3);
    });

    test('TEST-008 a persisted entry naming a preset is ignored', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(LayoutProfileStore.prefsKey, [
        jsonEncode(fixture('Sequential').toJson()),
      ]);

      final profiles = await LayoutProfileStore.loadAll();
      expect(
        profiles.where((p) => p.name == 'Sequential'),
        hasLength(1),
      );
      expect(
        profiles.firstWhere((p) => p.name == 'Sequential').isDeveloperPreset,
        isTrue,
      );
      expect(
        await LayoutProfileStore.saveProfile(fixture('Sequential')),
        isFalse,
      );
    });

    test('a rename preserves the layout', () async {
      await LayoutProfileStore.saveProfile(fixture('Old'));
      final old = (await LayoutProfileStore.loadAll()).firstWhere(
        (p) => p.name == 'Old',
      );
      expect(
        await LayoutProfileStore.saveProfile(
          LayoutProfile(name: 'New', layout: old.layout),
        ),
        isTrue,
      );
      await LayoutProfileStore.deleteProfile('Old');

      final profiles = await LayoutProfileStore.loadAll();
      expect(profiles.where((p) => p.name == 'Old'), isEmpty);
      expect(profiles.firstWhere((p) => p.name == 'New'), fixture('New'));
    });

    test('active name round-trips with a Sequential default', () async {
      expect(
        await LayoutProfileStore.loadActiveName(),
        LayoutProfileStore.defaultProfileName,
      );
      await LayoutProfileStore.saveActiveName('Mine');
      expect(await LayoutProfileStore.loadActiveName(), 'Mine');
    });
  });
}
