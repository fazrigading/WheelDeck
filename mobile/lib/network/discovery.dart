import 'package:multicast_dns/multicast_dns.dart';

import 'wheeldeck_client.dart';

/// The DNS-SD service type the desktop advertises under.
///
/// Discovery (TASK-030) queries this name; the desktop's advertiser will
/// register the same string so both sides stay in sync.
const String wheelDeckServiceType = '_wheeldeck._tcp.local';

/// A desktop server resolved through mDNS or entered manually.
class DiscoveredServer {
  const DiscoveredServer({
    required this.host,
    required this.port,
    required this.name,
  });

  /// IP address the WebSocket listener is reachable at.
  final String host;

  /// WebSocket port the desktop server listens on.
  final int port;

  /// Human-readable service instance name, for the selection UI.
  final String name;

  ConnectionTarget toConnectionTarget() => ConnectionTarget(
        mode: ConnectionMode.autoDiscover,
        ipAddress: host,
        port: port,
      );
}

/// Resolves advertised WheelDeck servers to dialable targets.
typedef ServerResolver = Future<List<DiscoveredServer>> Function();

/// Discovers desktop servers via mDNS and exposes manual-IP entry as the
/// fallback for networks that block multicast (public Wi-Fi with client
/// isolation, per the PRD).
class ServerDiscovery {
  ServerDiscovery({ServerResolver? resolve})
      : _resolve = resolve ?? MulticastResolver().resolve;

  final ServerResolver _resolve;

  /// Queries the network for advertised WheelDeck servers.
  Future<List<DiscoveredServer>> discover() => _resolve();

  /// Builds a manual target from a user-entered host and optional port.
  static ConnectionTarget manualTarget({
    required String host,
    int? port,
  }) =>
      ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: host,
        port: port ?? WheelDeckClient.defaultPort,
      );
}

/// Drives the [MDnsClient] through the PTR -> SRV -> A resolution chain.
class MulticastResolver {
  Future<List<DiscoveredServer>> resolve() async {
    final client = MDnsClient();
    try {
      await client.start();

      final pointers = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(wheelDeckServiceType),
          )
          .toList();

      final servers = <DiscoveredServer>[];
      for (final pointer in pointers) {
        final server = await _resolveInstance(client, pointer.domainName);
        if (server != null) {
          servers.add(server);
        }
      }

      return servers;
    } finally {
      client.stop();
    }
  }

  Future<DiscoveredServer?> _resolveInstance(
    MDnsClient client,
    String instanceName,
  ) async {
    final services = await client
        .lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(instanceName),
        )
        .toList();

    if (services.isEmpty) {
      return null;
    }

    final service = services.first;
    final addresses = await client
        .lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(service.target),
        )
        .toList();

    if (addresses.isEmpty) {
      return null;
    }

    return DiscoveredServer(
      host: addresses.first.address.address,
      port: service.port,
      name: _displayName(instanceName),
    );
  }

  String _displayName(String instanceName) {
    final suffix = '.$wheelDeckServiceType';
    return instanceName.endsWith(suffix)
        ? instanceName.substring(0, instanceName.length - suffix.length)
        : instanceName;
  }
}
