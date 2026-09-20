import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/settings_repository.dart';
import 'package:wheeldeck/data/services/camera_pad_mode.dart';
import 'package:wheeldeck/data/services/input_mapping.dart';
import 'package:wheeldeck/data/services/wheeldeck_client.dart';
import 'package:wheeldeck/ui/features/settings/view_models/settings_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InputMapping', () {
    test('defaults to gamepad', () {
      expect(InputMapping.fromWireValue(null), InputMapping.gamepad);
      expect(InputMapping.fromWireValue('nonsense'), InputMapping.gamepad);
    });

    test('parses both wire values', () {
      expect(InputMapping.fromWireValue('keyboard'), InputMapping.keyboard);
      expect(InputMapping.fromWireValue('gamepad'), InputMapping.gamepad);
    });

    test('load defaults to gamepad', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await InputMapping.load(), InputMapping.gamepad);
    });

    test('save/load round-trips', () async {
      SharedPreferences.setMockInitialValues({});
      await InputMapping.keyboard.save();
      expect(await InputMapping.load(), InputMapping.keyboard);
      await InputMapping.gamepad.save();
      expect(await InputMapping.load(), InputMapping.gamepad);
    });
  });

  test(
    'resetToDefaults restores gamepad on disk, not just in memory',
    () async {
      SharedPreferences.setMockInitialValues({
        'wheeldeck.input_mapping': 'keyboard',
      });
      final viewModel = SettingsViewModel(
        settingsRepository: const SettingsRepository(),
        connectionRepository: ConnectionRepository(
          client: WheelDeckClient(deviceId: 'test'),
        ),
      );
      addTearDown(viewModel.dispose);

      await viewModel.init();
      expect(viewModel.mapping, InputMapping.keyboard);

      await viewModel.resetToDefaults();
      expect(viewModel.mapping, InputMapping.gamepad);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(InputMapping.prefsKey), 'gamepad');
      expect(await InputMapping.load(), InputMapping.gamepad);
    },
  );

  test('resetToDefaults restores the camera pad mode on disk', () async {
    SharedPreferences.setMockInitialValues({
      'wheeldeck.camera_pad_mode': 'arrow',
    });
    final viewModel = SettingsViewModel(
      settingsRepository: const SettingsRepository(),
      connectionRepository: ConnectionRepository(
        client: WheelDeckClient(deviceId: 'test'),
      ),
    );
    addTearDown(viewModel.dispose);

    await viewModel.init();
    expect(viewModel.cameraPadMode, CameraPadMode.arrow);

    await viewModel.resetToDefaults();
    expect(viewModel.cameraPadMode, CameraPadMode.numpad);
    expect(await CameraPadMode.load(), CameraPadMode.numpad);
  });
}
