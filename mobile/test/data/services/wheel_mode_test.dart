import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/services/controller_preset.dart';
import 'package:wheeldeck/data/services/wheel_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WheelMode', () {
    test('fresh install defaults to rotatable', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await WheelMode.load(), WheelMode.rotatable);
    });

    test('round-trips gyro', () async {
      SharedPreferences.setMockInitialValues({});
      await WheelMode.gyro.save();
      expect(await WheelMode.load(), WheelMode.gyro);
    });

    test('unknown stored value falls back to rotatable', () async {
      SharedPreferences.setMockInitialValues(
          {'wheeldeck.wheel_mode': 'tilt'});
      expect(await WheelMode.load(), WheelMode.rotatable);
    });
  });

  group('RotationDegree', () {
    test('fresh install defaults to 900 for every preset', () async {
      SharedPreferences.setMockInitialValues({});
      for (final preset in GamePreset.values) {
        expect(await RotationDegree.load(preset), 900);
      }
    });

    test('allowed degrees round-trip per preset independently', () async {
      SharedPreferences.setMockInitialValues({});
      await RotationDegree.save(GamePreset.ets2, 270);
      await RotationDegree.save(GamePreset.generic, 1800);
      expect(await RotationDegree.load(GamePreset.ets2), 270);
      expect(await RotationDegree.load(GamePreset.generic), 1800);
    });

    test('invalid stored degree falls back to 900', () async {
      SharedPreferences.setMockInitialValues(
          {'wheeldeck.rotation_degree.ets2': 500});
      expect(await RotationDegree.load(GamePreset.ets2), 900);
    });

    test('allowed list matches spec', () {
      expect(RotationDegree.allowed, [180, 270, 900, 1080, 1800, 2520]);
    });
  });
}
