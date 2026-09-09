import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/onboarding_repository.dart';
import 'package:wheeldeck/data/services/permission_service.dart';
import 'package:wheeldeck/ui/features/onboarding/view_models/onboarding_view_model.dart';

class _FakePermissionService implements PermissionService {
  _FakePermissionService({
    this.motionSensorResult = PermissionStatus.granted,
    this.localNetworkResult = PermissionStatus.granted,
  });

  PermissionStatus motionSensorResult;
  PermissionStatus localNetworkResult;

  @override
  Future<PermissionStatus> requestMotionSensor() async => motionSensorResult;

  @override
  Future<PermissionStatus> requestLocalNetwork() async => localNetworkResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  OnboardingViewModel buildViewModel({
    PermissionStatus motion = PermissionStatus.granted,
    PermissionStatus local = PermissionStatus.granted,
  }) {
    return OnboardingViewModel(
      permissions: PermissionPrompts(
        service: _FakePermissionService(
          motionSensorResult: motion,
          localNetworkResult: local,
        ),
      ),
      onboardingRepository: const OnboardingRepository(),
    );
  }

  group('OnboardingViewModel', () {
    test('requestAndComplete records statuses and persists completion',
        () async {
      final viewModel = buildViewModel();
      const repository = OnboardingRepository();
      var notifyCount = 0;
      viewModel.addListener(() => notifyCount++);

      expect(await repository.isComplete(), isFalse);

      await viewModel.requestAndComplete();

      expect(viewModel.motionSensorStatus, PermissionStatus.granted);
      expect(viewModel.localNetworkStatus, PermissionStatus.granted);
      expect(viewModel.requesting, isFalse);
      expect(await repository.isComplete(), isTrue);
      expect(notifyCount, greaterThan(0));

      viewModel.dispose();
    });

    test('denials surface as non-fatal statuses', () async {
      final viewModel = buildViewModel(
        motion: PermissionStatus.denied,
        local: PermissionStatus.permanentlyDenied,
      );

      await viewModel.requestAndComplete();

      expect(viewModel.motionSensorStatus, PermissionStatus.denied);
      expect(viewModel.localNetworkStatus, PermissionStatus.permanentlyDenied);
      expect(viewModel.requesting, isFalse);

      viewModel.dispose();
    });

    test('complete persists without requesting permissions', () async {
      final viewModel = buildViewModel();
      const repository = OnboardingRepository();

      await viewModel.complete();

      expect(await repository.isComplete(), isTrue);

      viewModel.dispose();
    });
  });
}
