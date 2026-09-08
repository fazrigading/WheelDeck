import '../../domain/models/pedal_state.dart';
import '../../input/pedal_input.dart';

/// Single source of truth for analog pedal pressures.
///
/// Wraps the [PedalInput] service (drag mapping, spring-back release) and
/// exposes immutable [PedalState] snapshots to ViewModels.
class PedalRepository {
  PedalRepository({required PedalInput input}) : _input = input {
    _input.onPressureChanged(_onPressureChanged);
  }

  final PedalInput _input;
  PedalState _state = PedalState.released;
  void Function(PedalState state)? _onStateChanged;

  /// Current pressures as an immutable snapshot.
  PedalState get state => _state;

  /// Raw input for widgets that still bind to it directly (pedal panel during
  /// migration). New code should use [state] plus the command methods below.
  PedalInput get input => _input;

  /// Registers the callback that receives updated snapshots.
  void onStateChanged(void Function(PedalState state) callback) =>
      _onStateChanged = callback;

  /// Sets the pressure directly while the user drags the pedal bar.
  void setPressure(PedalType pedal, double pressure) =>
      _input.setPressure(pedal, pressure);

  /// Releases the pedal so it springs back toward rest.
  void release(PedalType pedal) => _input.release(pedal);

  /// Cancels any active release animations.
  void dispose() => _input.dispose();

  void _onPressureChanged(PedalType pedal, double pressure) {
    _state = PedalState(
      accelerator: pedal == PedalType.accelerator
          ? pressure
          : _state.accelerator,
      brake: pedal == PedalType.brake ? pressure : _state.brake,
      clutch:
          pedal == PedalType.clutch ? pressure : _state.clutch,
    );
    _onStateChanged?.call(_state);
  }
}
