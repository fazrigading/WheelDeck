import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../permissions.dart';

/// First-run onboarding screen that explains why motion sensor and local
/// network permissions are needed, then requests them.
///
/// Stores a completion flag in [SharedPreferences] so it only appears once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  /// Called when onboarding completes (permissions requested or skipped).
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _requesting = false;
  PermissionStatus? _motionSensorStatus;
  PermissionStatus? _localNetworkStatus;

  Future<void> _requestPermissions() async {
    setState(() => _requesting = true);

    final prompts = PermissionPrompts();
    final results = await prompts.requestAll();

    setState(() {
      _requesting = false;
      for (final result in results) {
        switch (result.type) {
          case PermissionType.motionSensor:
            _motionSensorStatus = result.status;
          case PermissionType.localNetwork:
            _localNetworkStatus = result.status;
        }
      }
    });

    await _complete();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wheeldeck.onboarding_complete', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.sports_motorsports,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to WheelDeck',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Turn your phone into a steering wheel\nand dashboard for PC simulators.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              _PermissionTile(
                icon: Icons.screen_rotation,
                title: 'Motion sensor',
                description: 'Reads your phone\'s gyroscope to map '
                    'steering rotation.',
                status: _motionSensorStatus,
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                icon: Icons.wifi,
                title: 'Local network',
                description: 'Discovers and connects to the WheelDeck '
                    'desktop server.',
                status: _localNetworkStatus,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _requesting ? null : _requestPermissions,
                  child: _requesting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _requesting ? null : _complete,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color? trailingColor;
    IconData? trailingIcon;
    if (status != null) {
      switch (status!) {
        case PermissionStatus.granted:
          trailingColor = Colors.green;
          trailingIcon = Icons.check_circle;
        case PermissionStatus.denied:
          trailingColor = colorScheme.error;
          trailingIcon = Icons.cancel;
        case PermissionStatus.permanentlyDenied:
          trailingColor = colorScheme.error;
          trailingIcon = Icons.block;
      }
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(description),
        trailing: trailingIcon != null
            ? Icon(trailingIcon, color: trailingColor)
            : null,
      ),
    );
  }
}
