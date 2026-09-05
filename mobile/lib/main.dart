import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/wheeldeck_client.dart';
import 'state/connection_coordinator.dart';
import 'ui/connection/connection_screen.dart';
import 'ui/driving/driving_view.dart';
import 'ui/onboarding/onboarding_screen.dart';

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

/// Switches between onboarding, the connection/pairing flow, and the driving
/// view based on onboarding completion and the coordinator's status.
class _Routing extends StatefulWidget {
  const _Routing();

  @override
  State<_Routing> createState() => _RoutingState();
}

class _RoutingState extends State<_Routing> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('wheeldeck.onboarding_complete') ?? false;
    if (mounted) {
      setState(() => _onboardingComplete = complete);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_onboardingComplete!) {
      return OnboardingScreen(onComplete: _checkOnboarding);
    }

    final coordinator = context.watch<ConnectionCoordinator>();
    final status = coordinator.status;

    if (status == ConnectionStatus.connected || coordinator.isPaused) {
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
