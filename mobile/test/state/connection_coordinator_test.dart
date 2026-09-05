import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/network/discovery.dart';
import 'package:wheeldeck/network/pairing.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';
import 'package:wheeldeck/state/connection_coordinator.dart';

class _MemoryStore implements SessionTokenStore {
  String? _token;

  @override
  Future<String?> load() async => _token;

  @override
  Future<void> save(String token) async => _token = token;
}

void main() {
  group('ConnectionCoordinator', () {
    test('refreshDiscovery updates the server list and notifies listeners',
        () async {
      var notifyCount = 0;
      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        resolver: () async => [
          DiscoveredServer(host: '10.0.0.1', port: 8765, name: 'Desktop'),
        ],
        store: _MemoryStore(),
      )..addListener(() => notifyCount++);

      await coordinator.refreshDiscovery();

      expect(coordinator.servers, hasLength(1));
      expect(coordinator.servers.first.name, 'Desktop');
      expect(notifyCount, greaterThan(0));
    });

    test('connect calls restoreSession then client.connect', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final dialed = <Uri>[];
      final store = _MemoryStore().._token = 'existing-token';

      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        connect: (uri) async {
          dialed.add(uri);
          return channel.local;
        },
        store: store,
      );

      await coordinator.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );

      expect(dialed, hasLength(1));
      expect(dialed.single, Uri.parse('ws://10.0.0.1:8765/'));
      expect(coordinator.status, ConnectionStatus.connected);
    });

    test('disconnect returns to disconnected', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});

      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
        store: _MemoryStore(),
      );

      await coordinator.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );

      expect(coordinator.status, ConnectionStatus.connected);

      await coordinator.disconnect();
      expect(coordinator.status, ConnectionStatus.disconnected);
    });

    test('status changes propagate from client to coordinator', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final statuses = <ConnectionStatus>[];
      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
        store: _MemoryStore(),
      );
      coordinator.addListener(() => statuses.add(coordinator.status));

      await coordinator.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );
      await coordinator.disconnect();

      expect(statuses, contains(ConnectionStatus.connected));
      expect(statuses, contains(ConnectionStatus.disconnected));
    });

    test('pairing challenge is set when desktop requires pairing', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});

      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
        store: _MemoryStore(),
      );

      await coordinator.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );

      expect(coordinator.pairingChallenge, isNull);

      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );

      expect(coordinator.pairingChallenge, isNotNull);
      expect(coordinator.pairingChallenge!.method, PairingMethod.pin);
    });

    test('pairingError is set after a rejected PIN submission', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});

      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
        store: _MemoryStore(),
      );

      await coordinator.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );

      // Initial pairing required.
      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );

      // Submit a PIN.
      coordinator.submitPairingCode('123456');
      expect(coordinator.pairingError, isFalse);

      // Desktop rejects.
      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );

      expect(coordinator.pairingError, isTrue);

      // Submit again — error should clear.
      coordinator.submitPairingCode('999999');
      expect(coordinator.pairingError, isFalse);
    });

    test('pairing challenge is cleared on successful connection', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});

      final coordinator = ConnectionCoordinator(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
        store: _MemoryStore(),
      );

      await coordinator.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.1',
        ),
      );

      channel.foreign.sink.add(
        jsonEncode({'type': 'pair_response', 'accepted': false}),
      );
      expect(coordinator.pairingChallenge, isNotNull);

      // Submit code and get accepted.
      coordinator.submitPairingCode('123456');
      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': true,
        'session_token': 'tok-1',
      }));

      expect(coordinator.pairingChallenge, isNull);
      expect(coordinator.status, ConnectionStatus.connected);
    });
  });
}
