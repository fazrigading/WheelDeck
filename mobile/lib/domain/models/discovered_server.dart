import 'package:freezed_annotation/freezed_annotation.dart';

import 'connection_mode.dart';
import 'connection_target.dart';

part 'discovered_server.freezed.dart';

/// A desktop server resolved through mDNS or entered manually.
@freezed
abstract class DiscoveredServer with _$DiscoveredServer {
  const factory DiscoveredServer({
    /// IP address the WebSocket listener is reachable at.
    required String host,

    /// WebSocket port the desktop server listens on.
    required int port,

    /// Human-readable service instance name, for the selection UI.
    required String name,
  }) = _DiscoveredServer;

  const DiscoveredServer._();

  ConnectionTarget toConnectionTarget() => ConnectionTarget(
        mode: ConnectionMode.autoDiscover,
        ipAddress: host,
        port: port,
      );
}
