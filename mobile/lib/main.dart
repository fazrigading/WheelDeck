import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'network/wheeldeck_client.dart';
import 'state/connection_coordinator.dart';
import 'ui/connection/connection_screen.dart';
import 'ui/driving/driving_view.dart';

void main() {
  runApp(const WheelDeckApp());
}

class WheelDeckApp extends StatelessWidget {
  const WheelDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConnectionCoordinator(
        deviceId: UniqueKey().toString(),
      )..refreshDiscovery(),
      child: const MaterialApp(
        home: _Routing(),
      ),
    );
  }
}

/// Switches between the connection/pairing flow and the driving view based on
/// the coordinator's [ConnectionCoordinator.status].
class _Routing extends StatelessWidget {
  const _Routing();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ConnectionCoordinator>().status;

    if (status == ConnectionStatus.connected) {
      return DrivingView(
        coordinator: context.read<ConnectionCoordinator>(),
      );
    }

    return const Scaffold(
      body: SafeArea(
        child: ConnectionScreen(),
      ),
    );
  }
}
