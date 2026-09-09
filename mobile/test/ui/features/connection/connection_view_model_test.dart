import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/server_discovery_repository.dart';
import 'package:wheeldeck/data/repositories/session_repository.dart';
import 'package:wheeldeck/domain/models/connection_mode.dart';
import 'package:wheeldeck/domain/models/connection_status.dart';
import 'package:wheeldeck/domain/models/connection_target.dart';
import 'package:wheeldeck/domain/models/discovered_server.dart';
import 'package:wheeldeck/domain/models/pairing_method.dart';
import 'package:wheeldeck/data/services/discovery.dart';
import 'package:wheeldeck/data/services/pairing.dart';
import 'package:wheeldeck/data/services/wheeldeck_client.dart';
import 'package:wheeldeck/ui/features/connection/view_models/connection_view_model.dart';

class _MemoryStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> load() async => token;

  @override
  Future<void> save(String value) async => token = value;
}

ConnectionViewModel buildViewModel({
  Future<StreamChannel<dynamic>> Function(Uri uri)? connect,
  ServerResolver? resolver,
  SessionTokenStore? store,
}) {
  final client = WheelDeckClient(deviceId: 'phone-1', connect: connect);
  final discovery = ServerDiscovery(resolve: resolver);
  final pairing = PairingController(
    store: store ?? _MemoryStore(),
    client: client,
  );
  return ConnectionViewModel(
    discoveryRepository: ServerDiscoveryRepository(discovery: discovery),
    connectionRepository: ConnectionRepository(client: client),
    sessionRepository: SessionRepository(pairing: pairing),
  );
}

void main() {
  group('ConnectionViewModel', () {
    test('refreshDiscovery updates the server list and notifies', () async {
      var notifyCount = 0;
      final viewModel = buildViewModel(
        resolver: () async => const [
          DiscoveredServer(host: '10.0.0.1', port: 8765, name: 'Desktop'),
        ],
      )..addListener(() => notifyCount++);

      await viewModel.refreshDiscovery();

      expect(viewModel.servers, hasLength(1));
      expect(viewModel.servers.first.name, 'Desktop');
      expect(notifyCount, greaterThan(0));
      viewModel.dispose();
    });

    test('connect without a session asks for a PIN', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final viewModel = buildViewModel(
        connect: (uri) async => channel.local,
      );

      await viewModel.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );

      expect(viewModel.pairingChallenge, isNotNull);
      expect(viewModel.pairingChallenge!.method, PairingMethod.pin);

      await viewModel.disconnect();
      viewModel.dispose();
    });

    test('pairingError is set after a rejected PIN submission', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final viewModel = buildViewModel(
        connect: (uri) async => channel.local,
      );

      await viewModel.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );
      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );

      viewModel.submitPairingCode('123456');
      expect(viewModel.pairingError, isFalse);

      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );
      expect(viewModel.pairingError, isTrue);

      viewModel.submitPairingCode('999999');
      expect(viewModel.pairingError, isFalse);

      await viewModel.disconnect();
      viewModel.dispose();
    });

    test('pairing challenge is cleared on successful connection', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final viewModel = buildViewModel(
        connect: (uri) async => channel.local,
      );

      await viewModel.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );
      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );
      expect(viewModel.pairingChallenge, isNotNull);

      viewModel.submitPairingCode('123456');
      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': true,
        'session_token': 'tok-1',
      }));

      expect(viewModel.pairingChallenge, isNull);
      expect(viewModel.status, ConnectionStatus.connected);

      await viewModel.disconnect();
      viewModel.dispose();
    });
  });
}
