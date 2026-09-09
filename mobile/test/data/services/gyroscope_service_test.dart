import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wheeldeck/data/services/gyroscope_service.dart';

void main() {
  group('GyroscopeService', () {
    test('integrates z angular velocity into a raw angle', () async {
      final events = StreamController<GyroscopeEvent>();
      var now = DateTime(2026, 1, 1);
      final service = GyroscopeService(
        eventStream: events.stream,
        clock: () => now,
      );

      final angles = <double>[];
      final sub = service.rawAngles.listen(angles.add);

      // First sample uses the 0.016s fallback dt. z = -2.0 (clockwise) must
      // read as positive steering.
      events.add(GyroscopeEvent(0, 0, -2.0, now));
      await Future<void>.delayed(Duration.zero);

      now = now.add(const Duration(milliseconds: 16));
      events.add(GyroscopeEvent(0, 0, 0.0, now));
      await Future<void>.delayed(Duration.zero);

      expect(angles, hasLength(2));
      expect(angles[0], closeTo(0.032, 1e-9));
      expect(angles[1], closeTo(0.032, 1e-9));

      await sub.cancel();
      await events.close();
    });

    test('clamps dt spikes and the angle range', () async {
      final events = StreamController<GyroscopeEvent>();
      var now = DateTime(2026, 1, 1);
      final service = GyroscopeService(
        eventStream: events.stream,
        clock: () => now,
      );

      final angles = <double>[];
      final sub = service.rawAngles.listen(angles.add);

      events.add(GyroscopeEvent(0, 0, -1000.0, now));
      await Future<void>.delayed(Duration.zero);

      // A 10s gap clamps dt to 0.1s; the angle clamps to ±pi.
      now = now.add(const Duration(seconds: 10));
      events.add(GyroscopeEvent(0, 0, -1000.0, now));
      await Future<void>.delayed(Duration.zero);

      expect(angles.last.abs(), closeTo(3.141592653589793, 1e-9));

      await sub.cancel();
      await events.close();
    });
  });
}
