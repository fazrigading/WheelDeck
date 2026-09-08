import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/data/repositories/connection_repository.dart';
import 'package:wheeldeck/data/repositories/pedal_repository.dart';
import 'package:wheeldeck/data/repositories/sensor_repository.dart';
import 'package:wheeldeck/input/dashboard_input.dart';
import 'package:wheeldeck/input/pedal_input.dart';
import 'package:wheeldeck/input/steering_sensor.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';
import 'package:wheeldeck/ui/features/driving/view_models/driving_view_model.dart';

class _Harness {
  _Harness._({
    required this.channel,
    required this.rawAngles,
    required this.sent,
    required this.viewModel,
  });

  final StreamChannelController<dynamic> channel;
  final StreamController<double> rawAngles;
  final List<dynamic> sent;
  final DrivingViewModel viewModel;

  static Future<_Harness> build({bool awaiting = false}) async {
    final channel = StreamChannelController<dynamic>(sync: true);
    final sent = <dynamic>[];
    channel.foreign.stream.listen(sent.add);
    final rawAngles = StreamController<double>();
    final client = WheelDeckClient(
      deviceId: 'phone-1',
      connect: (uri) async => channel.local,
    );
    final viewModel = DrivingViewModel(
      connectionRepository: ConnectionRepository(client: client),
      sensorRepository: SensorRepository(
        sensor: SteeringSensor(rawAngleStream: rawAngles.stream),
      ),
      pedalRepository: PedalRepository(input: PedalInput()),
      dashboardInput: DashboardInput(),
      initialAwaitingCalibration: awaiting,
    );

    await client.connect(
      const ConnectionTarget(
        mode: ConnectionMode.manual,
        ipAddress: '10.0.0.2',
      ),
    );
    sent.clear(); // Drop the connect-time heartbeat.

    return _Harness._(
      channel: channel,
      rawAngles: rawAngles,
      sent: sent,
      viewModel: viewModel,
    );
  }

  Map<String, dynamic> get lastSent =>
      jsonDecode(sent.last as String) as Map<String, dynamic>;

  /// Raw gyro angle producing [normalized] through the default sensor scaling
  /// (full lock at pi/4 rad).
  static double rawFor(double normalized) =>
      normalized * math.pi / 4;

  Future<void> tearDown() async {
    await rawAngles.close();
    viewModel.dispose();
    await channel.local.sink.close();
  }
}

void main() {
  group('DrivingViewModel', () {
    test('sensor angle updates steering and sends a state frame', () async {
      final h = await _Harness.build();

      h.rawAngles.add(_Harness.rawFor(0.2));
      await Future<void>.delayed(Duration.zero);

      expect(h.viewModel.steering.angle, closeTo(0.2, 1e-9));
      expect(h.sent, hasLength(1));
      expect(h.lastSent['type'], 'state');
      expect(h.lastSent['steering'], closeTo(0.2, 1e-9));

      await h.tearDown();
    });

    test('ignores sensor jitter inside the deadband', () async {
      final h = await _Harness.build();

      h.rawAngles.add(_Harness.rawFor(0.2));
      await Future<void>.delayed(Duration.zero);
      h.rawAngles.add(_Harness.rawFor(0.201));
      await Future<void>.delayed(Duration.zero);

      expect(h.sent, hasLength(1));

      await h.tearDown();
    });

    test('gates sensor and pedal input while awaiting calibration', () async {
      final h = await _Harness.build(awaiting: true);

      h.rawAngles.add(_Harness.rawFor(0.5));
      await Future<void>.delayed(Duration.zero);
      h.viewModel.setPedalPressure(PedalType.accelerator, 0.9);
      await Future<void>.delayed(Duration.zero);

      expect(h.viewModel.steering.angle, 0.0);
      expect(h.sent, isEmpty);

      // Confirming recenters the sensor on the last raw angle, so the next
      // push must move further to read as fresh steering.
      h.viewModel.confirmCalibration();
      expect(h.viewModel.awaitingCalibration, isFalse);

      h.rawAngles.add(_Harness.rawFor(0.8));
      await Future<void>.delayed(Duration.zero);

      expect(h.viewModel.steering.angle, closeTo(0.3, 1e-9));
      expect(h.sent, hasLength(1));

      await h.tearDown();
    });

    test('pedal pressure sends a state frame with pressures', () async {
      final h = await _Harness.build();

      h.viewModel.setPedalPressure(PedalType.accelerator, 0.85);
      await Future<void>.delayed(Duration.zero);

      expect(h.viewModel.pedals.accelerator, closeTo(0.85, 1e-9));
      expect(h.lastSent['type'], 'state');
      expect(h.lastSent['accelerator'], closeTo(0.85, 1e-9));

      await h.tearDown();
    });

    test('wheel drag maps ~200px to full lock and gates the sensor',
        () async {
      final h = await _Harness.build();

      h.viewModel.onWheelDragStart();
      h.rawAngles.add(_Harness.rawFor(0.9));
      await Future<void>.delayed(Duration.zero);
      expect(h.sent, isEmpty); // Sensor gated while dragging.

      h.viewModel.onWheelDragUpdate(100);
      expect(h.viewModel.steering.angle, closeTo(0.5, 1e-9));
      expect(h.lastSent['steering'], closeTo(0.5, 1e-9));

      h.viewModel.onWheelDragEnd();
      // Drag end recentered the sensor on the last raw angle, so pushing the
      // same raw value reads back as neutral steering again.
      h.rawAngles.add(_Harness.rawFor(0.9));
      await Future<void>.delayed(Duration.zero);
      expect(h.viewModel.steering.angle, closeTo(0.0, 1e-9));

      await h.tearDown();
    });

    test('dashboard activation sends a button frame', () async {
      final h = await _Harness.build();

      h.viewModel.dashboardInput.activate(
        ControlId.turnSignalLeft,
        ActionType.toggle,
      );
      await Future<void>.delayed(Duration.zero);

      expect(h.lastSent['type'], 'button');
      expect(h.lastSent['control'], 'turn_signal_left');
      expect(h.lastSent['action'], 'toggle');

      await h.tearDown();
    });

    test('setAwaitingCalibration syncs the gate without spamming', () async {
      final h = await _Harness.build();
      var count = 0;
      h.viewModel.addListener(() => count++);

      h.viewModel.setAwaitingCalibration(false); // No-op.
      expect(count, 0);

      h.viewModel.setAwaitingCalibration(true);
      expect(h.viewModel.awaitingCalibration, isTrue);
      expect(count, 1);

      await h.tearDown();
    });

    test('disconnect clears the gate', () async {
      final h = await _Harness.build(awaiting: true);

      await h.viewModel.disconnect();

      expect(h.viewModel.awaitingCalibration, isFalse);

      await h.tearDown();
    });

    test('init applies the persisted mapping best-effort', () async {
      final h = await _Harness.build();

      await h.viewModel.init(); // Must not throw without storage.

      await h.tearDown();
    });
  });
}
