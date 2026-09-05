import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/network/discovery.dart';
import 'package:wheeldeck/network/pairing.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';
import 'package:wheeldeck/state/connection_coordinator.dart';
import 'package:wheeldeck/ui/connection/connection_screen.dart';

/// A session-token store that lives only in memory so tests stay hermetic.
class _MemoryStore implements SessionTokenStore {
  String? _token;

  @override
  Future<String?> load() async => _token;

  @override
  Future<void> save(String token) async => _token = token;
}

/// Builds a [ConnectionCoordinator] with injectable network dependencies.
ConnectionCoordinator _buildCoordinator({
  String deviceId = 'phone-1',
  Future<StreamChannel<dynamic>> Function(Uri uri)? connect,
  ServerResolver? resolve,
  SessionTokenStore? store,
}) {
  return ConnectionCoordinator(
    deviceId: deviceId,
    connect: connect,
    resolver: resolve,
    store: store ?? _MemoryStore(),
  );
}

/// Pumps the [ConnectionScreen] wrapped in a provider that supplies the
/// given [coordinator].
Future<void> _pumpScreen(
  WidgetTester tester,
  ConnectionCoordinator coordinator,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: coordinator,
      child: const MaterialApp(
        home: ConnectionScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('discovery', () {
    testWidgets('lists discovered servers after refresh', (tester) async {
      final coordinator = _buildCoordinator(
        resolve: () async => [
          DiscoveredServer(name: 'Workshop', host: '10.0.0.5', port: 8765),
          DiscoveredServer(name: 'Garage', host: '10.0.0.7', port: 8765),
        ],
      );
      await coordinator.refreshDiscovery();
      await _pumpScreen(tester, coordinator);

      expect(find.text('Workshop'), findsOneWidget);
      expect(find.text('Garage'), findsOneWidget);
    });

    testWidgets('shows a placeholder when no servers are found', (tester) async {
      final coordinator = _buildCoordinator(resolve: () async => []);
      await coordinator.refreshDiscovery();
      await _pumpScreen(tester, coordinator);

      expect(find.textContaining('No servers'), findsOneWidget);
    });

    testWidgets('refresh button re-discovers servers', (tester) async {
      var callCount = 0;
      final coordinator = _buildCoordinator(
        resolve: () async {
          callCount++;
          if (callCount == 1) return [];
          return [
            DiscoveredServer(name: 'Workshop', host: '10.0.0.5', port: 8765),
          ];
        },
      );
      await coordinator.refreshDiscovery();
      await _pumpScreen(tester, coordinator);

      expect(find.textContaining('No servers'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Workshop'), findsOneWidget);
      expect(callCount, 2);
    });
  });

  group('manual entry', () {
    testWidgets('shows a manual IP entry field, port field, and connect button',
        (tester) async {
      final coordinator = _buildCoordinator(resolve: () async => []);
      await _pumpScreen(tester, coordinator);

      expect(find.byKey(const Key('manual-ip')), findsOneWidget);
      expect(find.byKey(const Key('manual-port')), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('port field is pre-filled with the default port',
        (tester) async {
      final coordinator = _buildCoordinator(resolve: () async => []);
      await _pumpScreen(tester, coordinator);

      final portField =
          tester.widget<TextField>(find.byKey(const Key('manual-port')));
      expect(portField.controller?.text, '8765');
    });

    testWidgets('connects to a manually entered host and port', (tester) async {
      final dialed = <Uri>[];
      final coordinator = _buildCoordinator(
        connect: (uri) async {
          dialed.add(uri);
          final controller = StreamChannelController<dynamic>(sync: false);
          controller.foreign.stream.listen((_) {});
          return controller.local;
        },
      );
      await _pumpScreen(tester, coordinator);

      await tester.enterText(find.byKey(const Key('manual-ip')), '192.168.1.10');
      await tester.enterText(find.byKey(const Key('manual-port')), '9000');
      await tester.tap(find.text('Connect'));
      await tester.pump(const Duration(milliseconds: 10));

      expect(dialed, hasLength(1));
      expect(dialed.single, Uri.parse('ws://192.168.1.10:9000/'));

      await coordinator.disconnect();
    });

    testWidgets('connects to a manually entered host with default port',
        (tester) async {
      final dialed = <Uri>[];
      final coordinator = _buildCoordinator(
        connect: (uri) async {
          dialed.add(uri);
          final controller = StreamChannelController<dynamic>(sync: false);
          controller.foreign.stream.listen((_) {});
          return controller.local;
        },
      );
      await _pumpScreen(tester, coordinator);

      await tester.enterText(find.byKey(const Key('manual-ip')), '10.0.0.99');
      await tester.tap(find.text('Connect'));
      await tester.pump(const Duration(milliseconds: 10));

      expect(dialed.single, Uri.parse('ws://10.0.0.99:8765/'));

      await coordinator.disconnect();
    });
  });

  group('pairing', () {
    late StreamChannelController<dynamic> channel;
    late List<dynamic> sent;

    setUp(() {
      channel = StreamChannelController<dynamic>(sync: false);
      sent = [];
      channel.foreign.stream.listen(sent.add);
    });

    tearDown(() async {
      await channel.local.sink.close();
    });

    testWidgets('shows a pairing prompt when the desktop requires pairing',
        (tester) async {
      final coordinator = _buildCoordinator(
        connect: (uri) async => channel.local,
      );
      await coordinator.connect(const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.1',
      ));
      await _pumpScreen(tester, coordinator);

      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': false,
      }));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('pairing-pin')), findsOneWidget);
      expect(find.textContaining('Enter the PIN'), findsOneWidget);

      await coordinator.disconnect();
    });

    testWidgets('submitting a PIN sends a pair_request', (tester) async {
      final coordinator = _buildCoordinator(
        connect: (uri) async => channel.local,
      );
      await coordinator.connect(const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.1',
      ));
      await _pumpScreen(tester, coordinator);

      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': false,
      }));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('pairing-pin')), '123456');
      await tester.tap(find.text('Submit'));
      await tester.pump();

      final request = jsonDecode(sent.last as String) as Map<String, dynamic>;
      expect(request['type'], 'pair_request');
      expect(request['device_id'], 'phone-1');
      expect(request['code'], '123456');

      await coordinator.disconnect();
    });

    testWidgets('shows an error after a rejected PIN', (tester) async {
      final coordinator = _buildCoordinator(
        connect: (uri) async => channel.local,
      );
      await coordinator.connect(const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.1',
      ));
      await _pumpScreen(tester, coordinator);

      // Desktop requires pairing.
      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': false,
      }));
      await tester.pump();
      await tester.pump();

      // Enter and submit a wrong PIN.
      await tester.enterText(find.byKey(const Key('pairing-pin')), '000000');
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // Desktop rejects it.
      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': false,
      }));
      await tester.pump();
      await tester.pump();

      expect(find.text('PIN incorrect. Try again.'), findsOneWidget);

      await coordinator.disconnect();
    });

    testWidgets('accepted pair_response proceeds to connected', (tester) async {
      final coordinator = _buildCoordinator(
        connect: (uri) async => channel.local,
        store: _MemoryStore(),
      );
      await coordinator.connect(const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.1',
      ));
      await _pumpScreen(tester, coordinator);

      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': false,
      }));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('pairing-pin')), '123456');
      await tester.tap(find.text('Submit'));
      await tester.pump();

      channel.foreign.sink.add(jsonEncode({
        'type': 'pair_response',
        'accepted': true,
        'session_token': 'tok-abc',
      }));
      await tester.pump();
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);

      await coordinator.disconnect();
    });
  });

  group('connection status', () {
    testWidgets('reports the connection status as Connected', (tester) async {
      final coordinator = _buildCoordinator(
        connect: (uri) async {
          final controller = StreamChannelController<dynamic>(sync: false);
          controller.foreign.stream.listen((_) {});
          return controller.local;
        },
      );
      await _pumpScreen(tester, coordinator);

      await coordinator.connect(const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.1',
      ));
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);

      await coordinator.disconnect();
    });

    testWidgets('shows a disconnect button when connected', (tester) async {
      final coordinator = _buildCoordinator(
        connect: (uri) async {
          final controller = StreamChannelController<dynamic>(sync: false);
          controller.foreign.stream.listen((_) {});
          return controller.local;
        },
      );
      await _pumpScreen(tester, coordinator);

      await coordinator.connect(const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.1',
      ));
      await tester.pump();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.wifi_off));
      await tester.pump();

      expect(find.text('Disconnected'), findsOneWidget);
    });

    testWidgets('shows a refresh and no disconnect when disconnected',
        (tester) async {
      final coordinator = _buildCoordinator(resolve: () async => []);
      await _pumpScreen(tester, coordinator);

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);
    });

    testWidgets('tapping a discovered server connects to it', (tester) async {
      final dialed = <Uri>[];
      final coordinator = _buildCoordinator(
        connect: (uri) async {
          dialed.add(uri);
          final controller = StreamChannelController<dynamic>(sync: false);
          controller.foreign.stream.listen((_) {});
          return controller.local;
        },
        resolve: () async => [
          DiscoveredServer(name: 'Workshop', host: '10.0.0.5', port: 8765),
        ],
      );
      await coordinator.refreshDiscovery();
      await _pumpScreen(tester, coordinator);

      await tester.tap(find.text('Workshop'));
      await tester.pump(const Duration(milliseconds: 10));

      expect(dialed, hasLength(1));
      expect(dialed.single, Uri.parse('ws://10.0.0.5:8765/'));

      await coordinator.disconnect();
    });
  });
}
