import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/services/spring_back.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpringBack', () {
    test('fresh install defaults to on', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SpringBack.load(), isTrue);
    });

    test('round-trips off', () async {
      SharedPreferences.setMockInitialValues({});
      await SpringBack.save(false);
      expect(await SpringBack.load(), isFalse);
    });

    test('reset to defaults restores on', () async {
      SharedPreferences.setMockInitialValues({SpringBack.prefsKey: false});
      await SpringBack.save(SpringBack.fallback);
      expect(await SpringBack.load(), isTrue);
    });
  });
}
