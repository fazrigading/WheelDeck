import 'package:freezed_annotation/freezed_annotation.dart';

import 'connection_mode.dart';

part 'connection_target.freezed.dart';

/// Default WebSocket port the desktop server listens on.
const int defaultWheelDeckPort = 8765;

/// The endpoint a connection should dial. Discovery produces `autoDiscover`
/// targets with a resolved [ipAddress]; manual entry sets [ipAddress] and
/// [port] directly.
@freezed
abstract class ConnectionTarget with _$ConnectionTarget {
  const factory ConnectionTarget({
    required ConnectionMode mode,
    String? ipAddress,
    int? port,
  }) = _ConnectionTarget;

  const ConnectionTarget._();

  /// Resolves to a `ws://` URI. Throws when no host is available yet.
  Uri resolve({int defaultPort = defaultWheelDeckPort}) {
    final host = ipAddress;
    if (host == null) {
      throw StateError('ConnectionTarget has no IP address to resolve.');
    }

    return Uri.parse('ws://$host:${port ?? defaultPort}/');
  }
}
