import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/settings_repository.dart';
import 'package:wheeldeck/input/input_mapping.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';
import 'package:wheeldeck/ui/features/settings/view_models/settings_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsViewModel', () {
    test('init loads the default mapping when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final viewModel = SettingsViewModel(
        settingsRepository: const SettingsRepository(),
        connectionRepository: ConnectionRepository(
          client: WheelDeckClient(
            deviceId: 'phone-1',
            connect: (uri) async => channel.local,
          ),
        ),
      );

      await viewModel.init();

      expect(viewModel.loaded, isTrue);
      expect(viewModel.mapping, InputMapping.keyboard);

      viewModel.dispose();
      await channel.local.sink.close();
    });

    test('init loads the persisted mapping', () async {
      SharedPreferences.setMockInitialValues(
        {InputMapping.prefsKey: InputMapping.gamepad.wireValue},
      );
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final viewModel = SettingsViewModel(
        settingsRepository: const SettingsRepository(),
        connectionRepository: ConnectionRepository(
          client: WheelDeckClient(
            deviceId: 'phone-1',
            connect: (uri) async => channel.local,
          ),
        ),
      );

      await viewModel.init();

      expect(viewModel.mapping, InputMapping.gamepad);

      viewModel.dispose();
      await channel.local.sink.close();
    });

    test('select persists the choice and forwards it to the desktop',
        () async {
      SharedPreferences.setMockInitialValues({});
      final channel = StreamChannelController<dynamic>(sync: true);
      final sent = <dynamic>[];
      channel.foreign.stream.listen(sent.add);
      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
      );
      final viewModel = SettingsViewModel(
        settingsRepository: const SettingsRepository(),
        connectionRepository: ConnectionRepository(client: client),
      );

      await client.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );
      sent.clear(); // Drop the connect-time heartbeat.

      await viewModel.select(InputMapping.gamepad);

      expect(viewModel.mapping, InputMapping.gamepad);
      expect(await InputMapping.load(), InputMapping.gamepad);

      final message = jsonDecode(sent.single as String) as Map<String, dynamic>;
      expect(message['type'], 'mapping');
      expect(message['mode'], 'gamepad');

      viewModel.dispose();
      await client.disconnect();
    });
  });
}
