import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/domain/models/connection_mode.dart';
import 'package:wheeldeck/domain/models/connection_status.dart';
import 'package:wheeldeck/domain/models/connection_target.dart';
import 'package:wheeldeck/input/dashboard_input.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';

void main() {
  group('ConnectionRepository', () {
    test('connect without a session token requests pairing', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
      );
      final repository = ConnectionRepository(client: client);

      await repository.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );

      expect(repository.status, ConnectionStatus.pairingRequired);

      await repository.disconnect();
    });

    test('connect with a session token reports connected', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
      );
      final repository = ConnectionRepository(client: client);
      repository.setSessionToken('saved-token');

      await repository.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );

      expect(repository.status, ConnectionStatus.connected);

      await repository.disconnect();
    });

    test('sendState frames a state message with a monotonic sequence',
        () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      final sent = <dynamic>[];
      channel.foreign.stream.listen(sent.add);
      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
      );
      final repository = ConnectionRepository(client: client);

      await repository.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );
      sent.clear(); // Drop the connect-time heartbeat.

      repository.sendState(
        steering: 0.5,
        accelerator: 0.1,
        brake: 0.2,
        clutch: 0.3,
      );

      final message = jsonDecode(sent.single as String) as Map<String, dynamic>;
      expect(message['type'], 'state');
      expect(message['seq'], 1);
      expect(message['steering'], 0.5);

      await repository.disconnect();
    });

    test('sendButtonEvent frames a button message using wire values',
        () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      final sent = <dynamic>[];
      channel.foreign.stream.listen(sent.add);
      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
      );
      final repository = ConnectionRepository(client: client);

      await repository.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );
      sent.clear(); // Drop the connect-time heartbeat.

      repository.sendButtonEvent(ControlId.headlightToggle, ActionType.toggle);

      final message = jsonDecode(sent.single as String) as Map<String, dynamic>;
      expect(message['type'], 'button');
      expect(message['control'], 'headlight_toggle');
      expect(message['action'], 'toggle');

      await repository.disconnect();
    });
  });
}
