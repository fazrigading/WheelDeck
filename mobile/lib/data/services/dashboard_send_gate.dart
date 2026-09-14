import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dashboard_input.dart';

/// Phone-held dashboard state machine on the send path.
///
/// Three jobs, one seam (spec testing seam 1):
/// - Drops controls whose per-mode binding is empty (`''` or `'-'`): the
///   phone sends nothing, in both mapping modes.
/// - Holds the headlight cycle OFF-Parking-Low-OFF: each [ControlId.headlightToggle]
///   tap advances the stage and sends the matching distinct ID
///   (`lights_parking` / `lights_lowbeam` / `lights_off`) as a toggle pulse.
///   High-beam passes through untouched.
/// - Holds turn/hazard state with a ~1.5Hz blink phase. Hazard drives both
///   signal visuals and suppresses individual toggles until cleared.
///
/// Blink visuals read [signalVisualActive]; the phase flips on [advanceBlink],
/// driven by a periodic timer when any signal is active (disabled with
/// `autoBlink: false` in tests).
enum LightStage { off, parking, low }

class DashboardSendGate extends ChangeNotifier {
  DashboardSendGate({
    required void Function(ControlId control, ActionType action) send,
    required String Function(ControlId control) bindingFor,
    this.blinkPhase = const Duration(milliseconds: 333),
    bool autoBlink = true,
  })  : _send = send,
        _bindingFor = bindingFor,
        _autoBlink = autoBlink;

  /// Full on-off blink rate in Hz; the phase flips every [blinkPhase].
  static const double blinkFrequencyHz = 1.5;

  /// Phase duration matching [blinkFrequencyHz] (1.5Hz = 667ms full cycle).
  static const Duration defaultBlinkPhase = Duration(milliseconds: 333);

  final void Function(ControlId control, ActionType action) _send;
  final String Function(ControlId control) _bindingFor;
  final bool _autoBlink;

  /// Phase flip interval. Defaults to [defaultBlinkPhase].
  final Duration blinkPhase;

  LightStage _lightStage = LightStage.off;
  bool _leftOn = false;
  bool _rightOn = false;
  bool _hazardOn = false;
  bool _blinkOn = false;
  Timer? _blinkTimer;

  /// Current headlight stage, for the three cycle visuals.
  LightStage get lightStage => _lightStage;

  bool get leftOn => _leftOn;
  bool get rightOn => _rightOn;
  bool get hazardOn => _hazardOn;

  /// Current blink phase. True = signals lit.
  bool get blinkOn => _blinkOn;

  /// Empty (`''`) or dash (`'-'`) means unbound: the phone sends nothing.
  static bool isUnbound(String binding) =>
      binding.isEmpty || binding == '-';

  bool shouldSend(ControlId control) => !isUnbound(_bindingFor(control));

  /// Whether the signal visual for [control] is lit right now. Hazard drives
  /// both sides; individuals show only their own held state.
  bool signalVisualActive(ControlId control) {
    switch (control) {
      case ControlId.turnSignalLeft:
        return _blinkOn && (_hazardOn || _leftOn);
      case ControlId.turnSignalRight:
        return _blinkOn && (_hazardOn || _rightOn);
      case ControlId.hazardLights:
        return _blinkOn && _hazardOn;
      default:
        return false;
    }
  }

  /// Routes one dashboard event: gates, translates, or suppresses it.
  void handle(ControlId control, ActionType action) {
    switch (control) {
      case ControlId.headlightToggle:
        _lightStage = switch (_lightStage) {
          LightStage.off => LightStage.parking,
          LightStage.parking => LightStage.low,
          LightStage.low => LightStage.off,
        };
        _sendIfBound(_cycleId, ActionType.toggle);
        return;
      case ControlId.lightsOff:
        _lightStage = LightStage.off;
        break;
      case ControlId.lightsParking:
        _lightStage = LightStage.parking;
        break;
      case ControlId.lightsLowbeam:
        _lightStage = LightStage.low;
        break;
      case ControlId.turnSignalLeft:
      case ControlId.turnSignalRight:
        // Hazard suppresses individual signals until cleared.
        if (_hazardOn) return;
        if (action == ActionType.toggle) {
          if (control == ControlId.turnSignalLeft) {
            _leftOn = !_leftOn;
          } else {
            _rightOn = !_rightOn;
          }
          _syncBlinkTimer();
        }
        break;
      case ControlId.hazardLights:
        if (action == ActionType.toggle) {
          _hazardOn = !_hazardOn;
          _syncBlinkTimer();
        }
        break;
      default:
        break;
    }
    _sendIfBound(control, action);
  }

  ControlId get _cycleId => switch (_lightStage) {
        LightStage.parking => ControlId.lightsParking,
        LightStage.low => ControlId.lightsLowbeam,
        LightStage.off => ControlId.lightsOff,
      };

  void _sendIfBound(ControlId control, ActionType action) {
    if (!shouldSend(control)) return;
    _send(control, action);
    notifyListeners();
  }

  /// Flips the blink phase. Called by the timer; public so tests can drive it.
  void advanceBlink() {
    _blinkOn = !_blinkOn;
    notifyListeners();
  }

  void _syncBlinkTimer() {
    final active = _leftOn || _rightOn || _hazardOn;
    _blinkTimer?.cancel();
    _blinkTimer = null;
    if (!active) {
      if (_blinkOn) {
        _blinkOn = false;
        notifyListeners();
      }
      return;
    }
    // Light immediately on activation; the timer alternates from there.
    if (!_blinkOn) _blinkOn = true;
    if (_autoBlink) {
      _blinkTimer = Timer.periodic(blinkPhase, (_) => advanceBlink());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    super.dispose();
  }
}
