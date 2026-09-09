import 'package:freezed_annotation/freezed_annotation.dart';

part 'steering_state.freezed.dart';

/// Normalized steering angle snapshot (-1.0 full left .. 1.0 full right).
@freezed
abstract class SteeringState with _$SteeringState {
  const factory SteeringState({
    @Default(0.0) double angle,
  }) = _SteeringState;

  const SteeringState._();

  /// Straight ahead.
  static const centered = SteeringState();
}
