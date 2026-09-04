import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/network/discovery.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';

void main() {
  group('DiscoveredServer', () {
    test('toConnectionTarget produces an auto-discover target', () {
      const server = DiscoveredServer(
        host: '192.168.1.50',
        port: 8765,
        name: 'Race Rig',
      );

      final target = server.toConnectionTarget();

      expect(target.mode, ConnectionMode.autoDiscover);
      expect(target.ipAddress, '192.168.1.50');
      expect(target.port, 8765);
    });
  });

  group('ServerDiscovery', () {
    test('discover returns one target per resolved server', () async {
      final discovery = ServerDiscovery(
        resolve: () async => const [
          DiscoveredServer(host: '10.0.0.8', port: 8765, name: 'Desktop A'),
          DiscoveredServer(host: '10.0.0.9', port: 8765, name: 'Desktop B'),
        ],
      );

      final targets = await discovery.discover();

      expect(targets, hasLength(2));
      expect(targets.first.host, '10.0.0.8');
      expect(targets.last.host, '10.0.0.9');
    });

    test('discover returns an empty list when no servers respond', () async {
      final discovery = ServerDiscovery(resolve: () async => const []);

      expect(await discovery.discover(), isEmpty);
    });

    test('discover propagates resolution failures', () async {
      final discovery = ServerDiscovery(
        resolve: () async => throw StateError('network down'),
      );

      expect(discovery.discover(), throwsStateError);
    });

    test('manualTarget builds a target from host and port', () {
      final target = ServerDiscovery.manualTarget(
        host: '192.168.1.7',
        port: 9000,
      );

      expect(target.mode, ConnectionMode.manual);
      expect(target.ipAddress, '192.168.1.7');
      expect(target.port, 9000);
    });

    test('manualTarget uses the default port when omitted', () {
      final target = ServerDiscovery.manualTarget(host: '192.168.1.7');

      expect(target.port, WheelDeckClient.defaultPort);
    });
  });
}
