import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/pedal_repository.dart';
import 'package:wheeldeck/data/repositories/sensor_repository.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/data/services/pedal_input.dart';
import 'package:wheeldeck/data/services/steering_sensor.dart';
import 'package:wheeldeck/data/services/wheeldeck_client.dart';
import 'package:wheeldeck/ui/features/driving/view_models/driving_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<double> rawAngles;
  late DrivingViewModel viewModel;

  DrivingViewModel buildViewModel() {
    final vm = DrivingViewModel(
      connectionRepository:
          ConnectionRepository(client: WheelDeckClient(deviceId: 'test')),
      sensorRepository: SensorRepository(
        sensor: SteeringSensor(rawAngleStream: rawAngles.stream),
      ),
      pedalRepository: PedalRepository(input: PedalInput()),
      dashboardInput: DashboardInput(),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  setUp(() {
    rawAngles = StreamController<double>.broadcast();
    addTearDown(rawAngles.close);
  });

  group('rotatable mode', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'wheeldeck.wheel_mode': 'rotatable',
        'wheeldeck.rotation_degree.ets2': 270,
      });
      viewModel = buildViewModel();
      await viewModel.init();
    });

    test('loads mode and degree', () {
      expect(viewModel.isRotatable, isTrue);
      expect(viewModel.rotationDegree, 270);
    });

    test('skips the calibration gate', () {
      viewModel.setAwaitingCalibration(true);
      expect(viewModel.awaitingCalibration, isFalse);
    });

    test('accepts wheel steering and ignores the gyro sensor', () async {
      viewModel.setRotatableSteering(0.5);
      expect(viewModel.steering.angle, 0.5);
      rawAngles.add(0.9);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.steering.angle, 0.5);
    });

    test('release back to zero transmits', () {
      viewModel.setRotatableSteering(0.5);
      viewModel.setRotatableSteering(0.0);
      expect(viewModel.steering.angle, 0.0);
    });
  });

  group('gyro mode', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'wheeldeck.wheel_mode': 'gyro'});
      viewModel = buildViewModel();
      await viewModel.init();
    });

    test('defaults to gyro and keeps the calibration gate', () {
      expect(viewModel.isRotatable, isFalse);
      viewModel.setAwaitingCalibration(true);
      expect(viewModel.awaitingCalibration, isTrue);
    });

    test('sensor angles flow through', () async {
      rawAngles.add(0.3);
      await Future<void>.delayed(Duration.zero);
      // SteeringSensor scales by maxRotationAngle (pi/4).
      expect(viewModel.steering.angle, closeTo(0.3 / (math.pi / 4), 0.01));
    });
  });

  test('refreshSettings picks up a mode switch and clears the gate',
      () async {
    SharedPreferences.setMockInitialValues(
        {'wheeldeck.wheel_mode': 'gyro'});
    viewModel = buildViewModel();
    await viewModel.init();
    viewModel.setAwaitingCalibration(true);
    expect(viewModel.awaitingCalibration, isTrue);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wheeldeck.wheel_mode', 'rotatable');
    await viewModel.refreshSettings();

    expect(viewModel.isRotatable, isTrue);
    expect(viewModel.awaitingCalibration, isFalse);
  });
}
