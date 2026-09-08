import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Stateless wrapper over the platform gyroscope.
///
/// Integrates Z-axis angular velocity (rad/s) into a raw angle so
/// [SteeringSensor] (via [SensorRepository]) consumes an already-integrated
/// value. The injected [eventStream]/[clock] seams keep this testable without
/// sensors.
class GyroscopeService {
  GyroscopeService({
    Stream<GyroscopeEvent>? eventStream,
    DateTime Function()? clock,
  })  : _eventStream = eventStream ?? gyroscopeEventStream(),
        _clock = clock ?? DateTime.now;

  final Stream<GyroscopeEvent> _eventStream;
  final DateTime Function() _clock;

  /// Raw integrated angle stream, clamped to ±pi to leave headroom around the
  /// pi/4 full-lock angle. Negated: positive gyro-z is counterclockwise on
  /// screen, but a right (clockwise) turn must read as positive steering.
  ///
  /// Single-subscription: listen once per service instance.
  Stream<double> get rawAngles {
    var rawGyroAngle = 0.0;
    DateTime? lastGyroAt;
    return _eventStream.map((e) {
      final now = _clock();
      final dt = lastGyroAt == null
          ? 0.016
          : now.difference(lastGyroAt!).inMicroseconds / 1000000.0;
      lastGyroAt = now;
      rawGyroAngle -= e.z * dt.clamp(0.0, 0.1);
      return rawGyroAngle.clamp(-math.pi, math.pi);
    });
  }
}
