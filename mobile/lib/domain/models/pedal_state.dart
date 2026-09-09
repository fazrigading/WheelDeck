import 'package:freezed_annotation/freezed_annotation.dart';

part 'pedal_state.freezed.dart';

/// Analog pedal pressure snapshot, each 0.0 (rest) .. 1.0 (full press).
@freezed
abstract class PedalState with _$PedalState {
  const factory PedalState({
    @Default(0.0) double accelerator,
    @Default(0.0) double brake,
    @Default(0.0) double clutch,
  }) = _PedalState;

  const PedalState._();

  /// All pedals at rest.
  static const released = PedalState();
}
