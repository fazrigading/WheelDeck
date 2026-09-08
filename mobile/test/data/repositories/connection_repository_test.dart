import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/domain/models/connection_mode.dart';
import 'package:wheeldeck/domain/models/connection_status.dart';
import 'package:wheeldeck/domain/models/connection_target.dart';
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
  });
}
