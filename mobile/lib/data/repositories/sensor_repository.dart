import '../services/steering_sensor.dart';

/// Single source of truth for the normalized steering angle (-1.0..1.0).
///
/// Wraps the [SteeringSensor] service (centering, sensitivity, clamping) so
/// ViewModels never touch sensor sampling directly.
class SensorRepository {
  SensorRepository({required this._sensor});

  final SteeringSensor _sensor;

  /// Registers the callback that receives the normalized steering angle.
  void onAngleChanged(void Function(double angle) callback) =>
      _sensor.onAngleChanged(callback);

  /// Starts sampling the raw angle stream.
  void start() => _sensor.start();

  /// Stops sampling.
  void stop() => _sensor.stop();

  /// Captures the current orientation as straight ahead.
  void setCenter() => _sensor.setCenter();

  /// Sets how much physical rotation maps to full lock.
  void setSensitivity(double value) => _sensor.setSensitivity(value);
}
