import 'dart:async';
import 'dart:math' as math;

/// Captures and normalizes the phone's steering rotation.
///
/// Raw gyroscope yaw is centered and scaled here so the wheel widget and the
/// network client both consume an already-calibrated -1.0..1.0 value.
class SteeringSensor {
  SteeringSensor({
    required this._rawAngleStream,
    this.maxRotationAngle = _defaultMaxRotationAngle,
  }) : assert(maxRotationAngle > 0, 'maxRotationAngle must be positive');

  /// Physical rotation, in radians, that maps to full lock at sensitivity 1.0.
  final double maxRotationAngle;

  static const double _defaultMaxRotationAngle = math.pi / 4;
  static const double _minSensitivity = 0.05;

  final Stream<double> _rawAngleStream;

  StreamSubscription<double>? _subscription;
  double _center = 0.0;
  double _lastRawAngle = 0.0;
  double _sensitivity = 1.0;
  void Function(double angle)? _onAngleChanged;

  /// Registers the callback that receives the normalized steering angle.
  void onAngleChanged(void Function(double angle) callback) {
    _onAngleChanged = callback;
  }

  /// Starts sampling raw gyroscope yaw.
  void start() {
    _subscription ??= _rawAngleStream.listen(_onRawAngle);
  }

  /// Stops sampling and cancels the underlying stream subscription.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Captures the current orientation as straight ahead.
  void setCenter() {
    _center = _lastRawAngle;
    _recompute();
  }

  /// Sets how much physical rotation maps to full lock. Higher values make the
  /// wheel respond more to the same rotation.
  void setSensitivity(double value) {
    _sensitivity = value < _minSensitivity ? _minSensitivity : value;
    _recompute();
  }

  void _onRawAngle(double raw) {
    _lastRawAngle = raw;
    _recompute();
  }

  void _recompute() {
    final delta = _lastRawAngle - _center;
    final normalized =
        (delta * _sensitivity / maxRotationAngle).clamp(-1.0, 1.0).toDouble();
    _onAngleChanged?.call(normalized);
  }
}
