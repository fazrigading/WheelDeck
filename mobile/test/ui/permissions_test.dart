import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/ui/permissions.dart';

class _FakePermissionService implements PermissionService {
  _FakePermissionService({
    this.motionSensorResult = PermissionStatus.granted,
    this.localNetworkResult = PermissionStatus.granted,
  });

  PermissionStatus motionSensorResult;
  PermissionStatus localNetworkResult;

  int motionSensorCalls = 0;
  int localNetworkCalls = 0;

  @override
  Future<PermissionStatus> requestMotionSensor() async {
    motionSensorCalls++;
    return motionSensorResult;
  }

  @override
  Future<PermissionStatus> requestLocalNetwork() async {
    localNetworkCalls++;
    return localNetworkResult;
  }
}

void main() {
  group('PermissionPrompts', () {
    test('requestMotionSensor returns granted when service grants', () async {
      final service = _FakePermissionService();
      final prompts = PermissionPrompts(service: service);

      final result = await prompts.requestMotionSensor();

      expect(result.type, PermissionType.motionSensor);
      expect(result.status, PermissionStatus.granted);
      expect(result.isGranted, isTrue);
      expect(service.motionSensorCalls, 1);
    });

    test('requestMotionSensor returns denied when service denies', () async {
      final service = _FakePermissionService(
        motionSensorResult: PermissionStatus.denied,
      );
      final prompts = PermissionPrompts(service: service);

      final result = await prompts.requestMotionSensor();

      expect(result.status, PermissionStatus.denied);
      expect(result.isGranted, isFalse);
    });

    test('requestMotionSensor returns permanentlyDenied', () async {
      final service = _FakePermissionService(
        motionSensorResult: PermissionStatus.permanentlyDenied,
      );
      final prompts = PermissionPrompts(service: service);

      final result = await prompts.requestMotionSensor();

      expect(result.status, PermissionStatus.permanentlyDenied);
      expect(result.isGranted, isFalse);
    });

    test('requestLocalNetwork returns granted when service grants', () async {
      final service = _FakePermissionService();
      final prompts = PermissionPrompts(service: service);

      final result = await prompts.requestLocalNetwork();

      expect(result.type, PermissionType.localNetwork);
      expect(result.status, PermissionStatus.granted);
      expect(result.isGranted, isTrue);
      expect(service.localNetworkCalls, 1);
    });

    test('requestLocalNetwork returns denied when service denies', () async {
      final service = _FakePermissionService(
        localNetworkResult: PermissionStatus.denied,
      );
      final prompts = PermissionPrompts(service: service);

      final result = await prompts.requestLocalNetwork();

      expect(result.status, PermissionStatus.denied);
      expect(result.isGranted, isFalse);
    });

    test('requestLocalNetwork returns permanentlyDenied', () async {
      final service = _FakePermissionService(
        localNetworkResult: PermissionStatus.permanentlyDenied,
      );
      final prompts = PermissionPrompts(service: service);

      final result = await prompts.requestLocalNetwork();

      expect(result.status, PermissionStatus.permanentlyDenied);
      expect(result.isGranted, isFalse);
    });

    test('requestAll returns both results in order', () async {
      final service = _FakePermissionService(
        motionSensorResult: PermissionStatus.granted,
        localNetworkResult: PermissionStatus.denied,
      );
      final prompts = PermissionPrompts(service: service);

      final results = await prompts.requestAll();

      expect(results, hasLength(2));
      expect(results[0].type, PermissionType.motionSensor);
      expect(results[0].isGranted, isTrue);
      expect(results[1].type, PermissionType.localNetwork);
      expect(results[1].isGranted, isFalse);
    });

    test('requestAll calls each service method once', () async {
      final service = _FakePermissionService();
      final prompts = PermissionPrompts(service: service);

      await prompts.requestAll();

      expect(service.motionSensorCalls, 1);
      expect(service.localNetworkCalls, 1);
    });

    test('default constructor uses platform service', () {
      // Verify the default constructor doesn't throw.
      // We can't test the platform service without native bindings,
      // but we can confirm the class constructs.
      expect(() => PermissionPrompts(), returnsNormally);
    });
  });
}
