import 'package:flutter/foundation.dart';

import '../../../../data/repositories/onboarding_repository.dart';
import '../../../../data/services/permission_service.dart';

/// Presentation state for the first-run onboarding flow.
///
/// Injects [PermissionPrompts] and [OnboardingRepository]; the View renders
/// via `ListenableBuilder` and calls [onComplete] after [requestAndComplete]
/// or [complete] finishes.
class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required PermissionPrompts permissions,
    required OnboardingRepository onboardingRepository,
  })  : _permissions = permissions,
        _onboardingRepository = onboardingRepository;

  final PermissionPrompts _permissions;
  final OnboardingRepository _onboardingRepository;

  bool _requesting = false;
  PermissionStatus? _motionSensorStatus;
  PermissionStatus? _localNetworkStatus;

  bool get requesting => _requesting;
  PermissionStatus? get motionSensorStatus => _motionSensorStatus;
  PermissionStatus? get localNetworkStatus => _localNetworkStatus;

  /// Requests both permissions, records the outcomes, and persists onboarding
  /// completion.
  Future<void> requestAndComplete() async {
    _requesting = true;
    notifyListeners();

    try {
      final results = await _permissions.requestAll();
      for (final result in results) {
        switch (result.type) {
          case PermissionType.motionSensor:
            _motionSensorStatus = result.status;
          case PermissionType.localNetwork:
            _localNetworkStatus = result.status;
        }
      }
      await _onboardingRepository.setComplete();
    } finally {
      _requesting = false;
      notifyListeners();
    }
  }

  /// Persists onboarding completion without requesting permissions.
  Future<void> complete() => _onboardingRepository.setComplete();
}
