import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';

void main() {
  test('sends a heartbeat with the session token on the interval', () {
    fakeAsync((async) {
      final controller = StreamChannelController<dynamic>(sync: true);
      final sent = <dynamic>[];
      controller.foreign.stream.listen(sent.add);

      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => controller.local,
      );
      client.setSessionToken('tok-123');

      client.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 2));

      final heartbeat = sent
          .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
          .firstWhere((m) => m['type'] == 'heartbeat');
      expect(heartbeat['session_token'], 'tok-123');

      client.disconnect();
    });
  });

  test('omits the session token when none is set', () {
    fakeAsync((async) {
      final controller = StreamChannelController<dynamic>(sync: true);
      final sent = <dynamic>[];
      controller.foreign.stream.listen(sent.add);

      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => controller.local,
      );

      client.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 2));

      final heartbeat = sent
          .map((m) => jsonDecode(m as String) as Map<String, dynamic>)
          .firstWhere((m) => m['type'] == 'heartbeat');
      expect(heartbeat.containsKey('session_token'), isFalse);

      client.disconnect();
    });
  });


  test('reconnects after the fixed interval when the socket closes', () {
    fakeAsync((async) {
      final controllers = <StreamChannelController<dynamic>>[];
      final statuses = <ConnectionStatus>[];
      var connectCount = 0;

      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async {
          connectCount++;
          final controller = StreamChannelController<dynamic>(sync: true);
          controllers.add(controller);
          return controller.local;
        },
      );
      client.onConnectionStatusChanged(statuses.add);

      client.connect(
        const ConnectionTarget(
          mode: ConnectionMode.manual,
          ipAddress: '10.0.0.2',
        ),
      );
      async.flushMicrotasks();

      controllers.first.foreign.sink.close();
      async.flushMicrotasks();

      expect(statuses, contains(ConnectionStatus.reconnecting));

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(connectCount, 2);
      expect(statuses.last, ConnectionStatus.connected);

      client.disconnect();
    });
  });
}
