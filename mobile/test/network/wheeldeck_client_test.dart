import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/input/dashboard_input.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';

void main() {
  late StreamChannelController<dynamic> controller;
  late List<dynamic> sent;
  late List<ConnectionStatus> statuses;
  late List<PairingChallenge> challenges;
  late WheelDeckClient client;

  WheelDeckClient buildClient() {
    sent = [];
    statuses = [];
    challenges = [];

    client = WheelDeckClient(
      deviceId: 'phone-1',
      connect: (uri) async {
        controller.local.sink.done.then((_) {});
        return controller.local;
      },
    );

    controller.foreign.stream.listen(sent.add);

    client
      ..onConnectionStatusChanged(statuses.add)
      ..onPairingRequired(challenges.add);

    return client;
  }

  setUp(() {
    controller = StreamChannelController<dynamic>(sync: true);
  });

  tearDown(() async {
    await client.disconnect();
  });

  test('connect resolves the target and reports connected', () async {
    buildClient();

    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    expect(client.status, ConnectionStatus.connected);
    expect(statuses, [
      ConnectionStatus.connecting,
      ConnectionStatus.connected,
    ]);
  });

  test('manual target without an IP address throws on connect', () async {
    buildClient();

    expect(
      () => client.connect(const ConnectionTarget(mode: ConnectionMode.manual)),
      throwsStateError,
    );
  });

  test('sendState frames a state message with a monotonic sequence', () async {
    buildClient();
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    client.sendState(steering: 0.42, accelerator: 0.85, brake: 0.0, clutch: 1.0);
    client.sendState(steering: -0.1, accelerator: 0.2, brake: 0.3, clutch: 0.4);

    expect(sent, hasLength(2));

    final first = jsonDecode(sent[0] as String) as Map<String, dynamic>;
    expect(first['type'], 'state');
    expect(first['seq'], 1);
    expect(first['steering'], 0.42);
    expect(first['accelerator'], 0.85);
    expect(first['brake'], 0.0);
    expect(first['clutch'], 1.0);

    final second = jsonDecode(sent[1] as String) as Map<String, dynamic>;
    expect(second['seq'], 2);
  });

  test('sendButtonEvent frames a button message using wire values', () async {
    buildClient();
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    client.sendButtonEvent(ControlId.turnSignalLeft, ActionType.toggle);

    final message = jsonDecode(sent.single as String) as Map<String, dynamic>;
    expect(message['type'], 'button');
    expect(message['control'], 'turn_signal_left');
    expect(message['action'], 'toggle');
  });

  test('submitPairingCode frames a pair_request with the device id', () async {
    buildClient();
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    client.submitPairingCode('123456');

    final message = jsonDecode(sent.single as String) as Map<String, dynamic>;
    expect(message['type'], 'pair_request');
    expect(message['device_id'], 'phone-1');
    expect(message['code'], '123456');
  });

  test('an accepted pair_response stays connected', () async {
    buildClient();
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    controller.foreign.sink.add(
      jsonEncode({
        'type': 'pair_response',
        'device_id': 'phone-1',
        'accepted': true,
        'session_token': 'tok',
      }),
    );

    expect(client.status, ConnectionStatus.connected);
    expect(challenges, isEmpty);
  });

  test('a rejected pair_response requests pairing', () async {
    buildClient();
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

    expect(client.status, ConnectionStatus.pairingRequired);
    expect(challenges, hasLength(1));
    expect(challenges.single.method, PairingMethod.pin);
  });

  test('disconnect closes the socket and reports disconnected', () async {
    buildClient();
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    await client.disconnect();

    expect(client.status, ConnectionStatus.disconnected);
    expect(statuses.last, ConnectionStatus.disconnected);
  });

  test('a remote close reports reconnecting', () async {
    buildClient();
    await client.connect(
      const ConnectionTarget(mode: ConnectionMode.manual, ipAddress: '10.0.0.2'),
    );

    await controller.foreign.sink.close();

    expect(client.status, ConnectionStatus.reconnecting);
  });
}
