import 'package:flutter/material.dart';

import 'connection_coordinator.dart';

/// Watches OS-level lifecycle events and pauses/resumes the session through
/// the [ConnectionCoordinator].
///
/// Register this as a [WidgetsBindingObserver] during the driving view's
/// [State.initState] and remove it in [State.dispose].
class LifecycleObserver extends WidgetsBindingObserver {
  LifecycleObserver({required this.coordinator});

  final ConnectionCoordinator coordinator;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        coordinator.pause();
      case AppLifecycleState.resumed:
        coordinator.resume();
      case AppLifecycleState.hidden:
        break;
    }
  }
}
