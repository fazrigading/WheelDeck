import '../../domain/models/connection_target.dart';
import '../../domain/models/discovered_server.dart';
import '../services/discovery.dart';

/// Single source of truth for discovered servers.
///
/// Wraps the stateless [ServerDiscovery] service, caches the last sweep, and
/// exposes domain models to ViewModels.
class ServerDiscoveryRepository {
  ServerDiscoveryRepository({required this._discovery});

  final ServerDiscovery _discovery;
  List<DiscoveredServer> _cached = const [];

  /// Last discovery results as an immutable snapshot.
  List<DiscoveredServer> get servers => List.unmodifiable(_cached);

  /// Runs an mDNS sweep and caches the results.
  Future<List<DiscoveredServer>> refresh() async {
    final servers = await _discovery.discover();
    _cached = List.unmodifiable(servers);
    return servers;
  }

  /// Builds a manual target from user-entered host and optional port.
  static ConnectionTarget manualTarget({required String host, int? port}) =>
      ServerDiscovery.manualTarget(host: host, port: port);
}
