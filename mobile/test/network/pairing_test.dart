import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/network/pairing.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';

class _MemoryTokenStore implements SessionTokenStore {
  String? _token;
  int saveCount = 0;

  @override
  Future<String?> load() async => _token;

  @override
  Future<void> save(String token) async {
    saveCount++;
    _token = token;
  }
}

void main() {
  late StreamChannelController<dynamic> controller;
  late List<dynamic> sent;
  late _MemoryTokenStore store;
  late WheelDeckClient client;
  late PairingController pairing;

  setUp(() {
    controller = StreamChannelController<dynamic>(sync: true);
    sent = [];
    store = _MemoryTokenStore();
    client = WheelDeckClient(
      deviceId: 'phone-1',
      connect: (uri) async => controller.local,
    );
    controller.foreign.stream.listen(sent.add);
    pairing = PairingController(store: store, client: client);
  });

  tearDown(() async {
    await controller.local.sink.close();
  });

  test('restoreSession returns the stored token', () async {
    store._token = 'persisted-token';

    expect(await pairing.restoreSession(), 'persisted-token');
  });

  test('restoreSession returns null when nothing is stored', () async {
    expect(await pairing.restoreSession(), isNull);
  });

  test('submitPairingCode sends a pair_request through the client', () async {
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    pairing.submitPairingCode('123456');

    final message = jsonDecode(sent.single as String) as Map<String, dynamic>;
    expect(message['type'], 'pair_request');
    expect(message['device_id'], 'phone-1');
    expect(message['code'], '123456');
  });

  test('an accepted pair_response persists the session token', () async {
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    controller.foreign.sink.add(
      jsonEncode({
        'type': 'pair_response',
        'device_id': 'phone-1',
        'accepted': true,
        'session_token': 'fresh-token',
      }),
    );

    expect(await store.load(), 'fresh-token');
    expect(store.saveCount, 1);
  });

  test('a rejected pair_response does not persist a token', () async {
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    controller.foreign.sink.add(
      jsonEncode({
        'type': 'pair_response',
        'device_id': 'phone-1',
        'accepted': false,
      }),
    );

    expect(await store.load(), isNull);
    expect(store.saveCount, 0);
  });
}
