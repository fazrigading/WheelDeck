import 'dart:async';
import 'dart:math' as math;

enum PedalType { accelerator, brake, clutch }

enum ReleaseCurve { linear, easeOut, easeInOut }

/// Maps touch drag positions to analog pedal pressure and animates the
/// spring-back release when a pedal is let go.
class PedalInput {
  PedalInput({
    this.releaseDuration = const Duration(milliseconds: 300),
    this._releaseCurve = ReleaseCurve.linear,
  });

  final Duration releaseDuration;
  ReleaseCurve _releaseCurve;

  final Map<PedalType, double> _pressures = {
    for (final pedal in PedalType.values) pedal: 0.0,
  };
  final Map<PedalType, Timer?> _releaseTimers = {
    for (final pedal in PedalType.values) pedal: null,
  };

  void Function(PedalType pedal, double pressure)? _onPressureChanged;

  /// Registers the callback that receives the current pressure for a pedal.
  void onPressureChanged(
    void Function(PedalType pedal, double pressure) callback,
  ) {
    _onPressureChanged = callback;
  }

  /// Selects the spring-back curve used when a pedal is released.
  void setReleaseCurve(ReleaseCurve curve) {
    _releaseCurve = curve;
  }

  /// Reports the current pressure of a pedal in the 0.0..1.0 range.
  double pressureOf(PedalType pedal) => _pressures[pedal] ?? 0.0;

  /// Sets the pressure directly while the user drags the pedal bar.
  void setPressure(PedalType pedal, double pressure) {
    _cancelRelease(pedal);
    final clamped = pressure.clamp(0.0, 1.0).toDouble();
    _emit(pedal, clamped);
  }

  /// Releases the pedal so it springs back toward rest.
  void release(PedalType pedal) {
    final current = _pressures[pedal] ?? 0.0;
    if (current <= 0.0) return;
    _startRelease(pedal, current);
  }

  /// Cancels any active release animations.
  void dispose() {
    for (final pedal in PedalType.values) {
      _cancelRelease(pedal);
    }
  }

  void _startRelease(PedalType pedal, double start) {
    _cancelRelease(pedal);
    if (releaseDuration.inMicroseconds <= 0) {
      _emit(pedal, 0.0);
      return;
    }

    const tick = Duration(milliseconds: 16);
    final stopwatch = Stopwatch()..start();

    _releaseTimers[pedal] = Timer.periodic(tick, (timer) {
      final progress = (stopwatch.elapsedMicroseconds /
              releaseDuration.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();
      final eased = _applyCurve(progress);
      final pressure = start * (1.0 - eased);

      if (progress >= 1.0) {
        timer.cancel();
        _releaseTimers[pedal] = null;
        _emit(pedal, 0.0);
      } else {
        _emit(pedal, pressure);
      }
    });
  }

  void _cancelRelease(PedalType pedal) {
    _releaseTimers[pedal]?.cancel();
    _releaseTimers[pedal] = null;
  }

  double _applyCurve(double progress) {
    switch (_releaseCurve) {
      case ReleaseCurve.linear:
        return progress;
      case ReleaseCurve.easeOut:
        return 1.0 - math.pow(1.0 - progress, 2).toDouble();
      case ReleaseCurve.easeInOut:
        return progress * progress * (3.0 - 2.0 * progress);
    }
  }

  void _emit(PedalType pedal, double pressure) {
    _pressures[pedal] = pressure;
    _onPressureChanged?.call(pedal, pressure);
  }
}
