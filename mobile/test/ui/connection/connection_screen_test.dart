import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:wheeldeck/network/discovery.dart';
import 'package:wheeldeck/network/pairing.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';
import 'package:wheeldeck/ui/connection/connection_screen.dart';

/// A session-token store that lives only in memory so tests stay hermetic.
class _MemoryStore implements SessionTokenStore {
  String? _token;

  @override
  Future<String?> load() async => _token;

  @override
  Future<void> save(String token) async => _token = token;
}

ServerDiscovery _fakeDiscovery(List<DiscoveredServer> servers) =>
    ServerDiscovery(resolve: () async => servers);

void main() {
  testWidgets('lists discovered servers', (tester) async {
    final discovery = _fakeDiscovery([
      DiscoveredServer(name: 'Workshop', host: '10.0.0.5', port: 8765),
      DiscoveredServer(name: 'Garage', host: '10.0.0.7', port: 8765),
    ]);
    final pairing = PairingController(
      store: _MemoryStore(),
      client: WheelDeckClient(deviceId: 'phone-1', connect: (uri) async {
        throw UnimplementedError('no real connection in this test');
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectionScreen(discovery: discovery, pairing: pairing)),
    ));
    await tester.pump();

    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
  });

  testWidgets('shows a placeholder when no servers are found', (tester) async {
    final discovery = _fakeDiscovery([]);
    final pairing = PairingController(
      store: _MemoryStore(),
      client: WheelDeckClient(deviceId: 'phone-1', connect: (uri) async {
        throw UnimplementedError('no real connection in this test');
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectionScreen(discovery: discovery, pairing: pairing)),
    ));
    await tester.pump();

    expect(find.textContaining('No servers'), findsOneWidget);
  });

  testWidgets('shows a manual IP entry field and connect button',
      (tester) async {
    final discovery = _fakeDiscovery([]);
    final pairing = PairingController(
      store: _MemoryStore(),
      client: WheelDeckClient(deviceId: 'phone-1', connect: (uri) async {
        throw UnimplementedError('no real connection in this test');
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectionScreen(discovery: discovery, pairing: pairing)),
    ));
    await tester.pump();

    expect(find.byKey(const Key('manual-ip')), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('shows a pairing prompt when the desktop requires pairing',
      (tester) async {
    final controller = StreamChannelController<dynamic>(sync: false);
    controller.foreign.stream.listen((_) {});

    final client = WheelDeckClient(
      deviceId: 'phone-1',
      connect: (uri) async => controller.local,
    );
    final pairing = PairingController(store: _MemoryStore(), client: client);
    final discovery = _fakeDiscovery([]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectionScreen(discovery: discovery, pairing: pairing)),
    ));
    await tester.pump();

    await client.connect(const ConnectionTarget(
        mode: ConnectionMode.manual, ipAddress: '10.0.0.1'));
    await tester.pump();

    controller.foreign.sink
        .add(jsonEncode({'type': 'pair_response', 'accepted': false}));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('pairing-pin')), findsOneWidget);
    expect(find.textContaining('Pairing Process'), findsOneWidget);

    await client.disconnect();
  });

  testWidgets('reports the connection status as Connected', (tester) async {
    final controller = StreamChannelController<dynamic>(sync: false);
    controller.foreign.stream.listen((_) {});

    final client = WheelDeckClient(
      deviceId: 'phone-1',
      connect: (uri) async => controller.local,
    );
    final pairing = PairingController(store: _MemoryStore(), client: client);
    final discovery = _fakeDiscovery([]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectionScreen(discovery: discovery, pairing: pairing)),
    ));
    await tester.pump();

    await client.connect(const ConnectionTarget(
        mode: ConnectionMode.manual, ipAddress: '10.0.0.1'));
    await tester.pump();

    expect(find.textContaining('Connected'), findsOneWidget);

    await client.disconnect();
  });

  testWidgets('tapping a discovered server connects to it', (tester) async {
    final dialed = <Uri>[];
    final client = WheelDeckClient(
      deviceId: 'phone-1',
      connect: (uri) async {
        dialed.add(uri);
        final controller = StreamChannelController<dynamic>(sync: false);
        controller.foreign.stream.listen((_) {});
        return controller.local;
      },
    );
    final pairing = PairingController(store: _MemoryStore(), client: client);
    final discovery =
        _fakeDiscovery([DiscoveredServer(name: 'Workshop', host: '10.0.0.5', port: 8765)]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ConnectionScreen(discovery: discovery, pairing: pairing)),
    ));
    await tester.pump();

    await tester.tap(find.text('Workshop'));
    await tester.pump(const Duration(milliseconds: 10));

    expect(dialed, hasLength(1));
    expect(dialed.single, Uri.parse('ws://10.0.0.5:8765/'));

    await client.disconnect();
  });
}
