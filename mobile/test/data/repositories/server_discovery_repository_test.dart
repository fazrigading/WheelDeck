import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/repositories/server_discovery_repository.dart';
import 'package:wheeldeck/domain/models/connection_mode.dart';
import 'package:wheeldeck/network/discovery.dart';

void main() {
  group('ServerDiscoveryRepository', () {
    test('refresh caches servers and exposes immutable snapshots', () async {
      final repository = ServerDiscoveryRepository(
        discovery: ServerDiscovery(
          resolve: () async => const [
            DiscoveredServer(host: '10.0.0.1', port: 8765, name: 'Desktop'),
          ],
        ),
      );

      expect(repository.servers, isEmpty);

      final servers = await repository.refresh();

      expect(servers, hasLength(1));
      expect(repository.servers.single.name, 'Desktop');
      expect(
        () => (repository.servers as List).add(
          const DiscoveredServer(host: 'x', port: 1, name: 'y'),
        ),
        throwsUnsupportedError,
      );
    });

    test('manualTarget builds a manual connection target', () {
      final target = ServerDiscoveryRepository.manualTarget(
        host: '192.168.1.7',
        port: 9000,
      );

      expect(target.mode, ConnectionMode.manual);
      expect(target.ipAddress, '192.168.1.7');
      expect(target.port, 9000);
    });
  });
}
