import 'package:flutter/material.dart';

import '../../data/repositories/onboarding_repository.dart';
import '../../data/services/permission_service.dart';
import '../features/onboarding/view_models/onboarding_view_model.dart';

/// First-run onboarding screen that explains why motion sensor and local
/// network permissions are needed, then requests them.
///
/// Lean widget: permission state lives in [OnboardingViewModel] and the body
/// rebuilds via `ListenableBuilder`. Completion is persisted through
/// [OnboardingRepository] so this screen only appears once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete, this.viewModel});

  /// Called when onboarding completes (permissions requested or skipped).
  final VoidCallback onComplete;

  /// Override for tests. When omitted, the state builds a live view model.
  final OnboardingViewModel? viewModel;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    final override = widget.viewModel;
    if (override != null) {
      _viewModel = override;
      _ownsViewModel = false;
    } else {
      _viewModel = OnboardingViewModel(
        permissions: PermissionPrompts(),
        onboardingRepository: const OnboardingRepository(),
      );
      _ownsViewModel = true;
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await _viewModel.requestAndComplete();
    if (mounted) {
      widget.onComplete();
    }
  }

  Future<void> _skip() async {
    await _viewModel.complete();
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, _) {
              final requesting = _viewModel.requesting;
              return Column(
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
                    status: _viewModel.motionSensorStatus,
                  ),
                  const SizedBox(height: 16),
                  _PermissionTile(
                    icon: Icons.wifi,
                    title: 'Local network',
                    description: 'Discovers and connects to the WheelDeck '
                        'desktop server.',
                    status: _viewModel.localNetworkStatus,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: requesting ? null : _requestPermissions,
                      child: requesting
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
                    onPressed: requesting ? null : _skip,
                    child: const Text('Skip for now'),
                  ),
                ],
              );
            },
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
