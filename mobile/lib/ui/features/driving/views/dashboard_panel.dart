import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import '../../../../data/services/dashboard_visibility.dart';
import '../../../../data/services/engine_start_mode.dart';

/// The truck-styled dashboard control grid.
///
/// Renders the always-shown [coreControls] plus the visible
/// [DashboardVisibility.toggleable] extras, and forwards activation events to
/// [DashboardInput]. Turn signals never appear in this shared wrap — the
/// rotatable grid's block A slots and the gyro signal row own them — but
/// signal cells rendered elsewhere are [DashboardControl]s with the gate's
/// straight-arrow icons and blink. Unbound controls (empty per-mode binding)
/// render disabled with a "—" badge; tapping one calls [onBindRequested]
/// instead of sending.
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.input,
    required this.bindingFor,
    this.gate,
    this.visibleExtras = DashboardVisibility.defaults,
    this.excluded = const {},
    this.engineStartMode = EngineStartMode.holdConfirm,
    this.onBindRequested,
  });

  final DashboardInput input;

  /// Resolves the per-mode binding label for a control. Empty or `-` means
  /// unbound: the button renders disabled and sends nothing.
  final String Function(ControlId control) bindingFor;

  /// Phone-held light/signal state for blink and cycle visuals. Null in tests
  /// that only assert tap-to-event mapping.
  final DashboardSendGate? gate;

  final Set<ControlId> visibleExtras;
  final Set<ControlId> excluded;
  final EngineStartMode engineStartMode;
  final ValueChanged<ControlId>? onBindRequested;

  /// Always-shown grid controls (labels + IDs). Turn signals are excluded by
  /// design; the rotatable grid's block A slots and the gyro signal row render
  /// them as [DashboardControl]s instead.
  static const coreEntries = [
    _DashboardEntry('LIGHT', ControlId.headlightToggle),
    _DashboardEntry('BEAM', ControlId.highBeamToggle),
    _DashboardEntry('CRUISE', ControlId.cruiseToggle),
    _DashboardEntry('RESUME', ControlId.cruiseSetResume),
    _DashboardEntry('PARK', ControlId.parkingBrake),
    _DashboardEntry('WIPE', ControlId.wipers),
    _DashboardEntry('START', ControlId.engineStart),
    _DashboardEntry('HAZARD', ControlId.hazardLights),
    _DashboardEntry('BEACON', ControlId.beaconLights),
    _DashboardEntry('FLASH', ControlId.flasher),
    _DashboardEntry('HORN', ControlId.horn),
    _DashboardEntry('TRAILER', ControlId.trailer),
    _DashboardEntry('AXLE', ControlId.liftDropAxle),
    _DashboardEntry('CAM', ControlId.cameraView),
  ];

  /// Test seam: IDs the grid always renders.
  static const coreControls = [
    ControlId.headlightToggle,
    ControlId.highBeamToggle,
    ControlId.cruiseToggle,
    ControlId.cruiseSetResume,
    ControlId.parkingBrake,
    ControlId.wipers,
    ControlId.engineStart,
    ControlId.hazardLights,
    ControlId.beaconLights,
    ControlId.flasher,
    ControlId.horn,
    ControlId.trailer,
    ControlId.liftDropAxle,
    ControlId.cameraView,
  ];

  /// Grid label for any shown control (core or extra), for dialogs.
  static String gridLabel(ControlId control) {
    for (final entry in coreEntries) {
      if (entry.control == control) return entry.label;
    }
    return labelFor(control);
  }

  /// Symbol icons for the turn-signal and audio-row cells; null renders the
  /// text label.
  static IconData? iconFor(ControlId? control) => switch (control) {
    ControlId.turnSignalLeft => Icons.arrow_back,
    ControlId.turnSignalRight => Icons.arrow_forward,
    ControlId.audioVolumeDown => Icons.volume_down,
    ControlId.audioPrevious => Icons.skip_previous,
    ControlId.audioPlayPause => Icons.play_arrow,
    ControlId.audioNext => Icons.skip_next,
    ControlId.audioVolumeUp => Icons.volume_up,
    _ => null,
  };

  /// Short grid labels for the toggleable extras.
  static String labelFor(ControlId control) {
    switch (control) {
      case ControlId.gearUp:
        return 'GEAR+';
      case ControlId.gearDown:
        return 'GEAR-';
      case ControlId.engineBrake:
        return 'E-BRK';
      case ControlId.airHorn:
        return 'AIR';
      case ControlId.differentialLock:
        return 'DIFF';
      case ControlId.retarderIncrease:
        return 'RET+';
      case ControlId.retarderDecrease:
        return 'RET-';
      case ControlId.quickInfo:
        return 'INFO';
      case ControlId.mirrorToggle:
        return 'MIRROR';
      case ControlId.hudWidgets:
        return 'HUD';
      case ControlId.vehicleAdjustment:
        return 'VEH';
      case ControlId.navigationZoomOut:
        return 'NAV';
      case ControlId.widgetOptions:
        return 'WIDGET';
      case ControlId.services:
        return 'SVC';
      case ControlId.quickSave:
        return 'SAVE';
      case ControlId.quickLoad:
        return 'LOAD';
      case ControlId.screenshot:
        return 'SHOT';
      case ControlId.garageManager:
        return 'GARAGE';
      case ControlId.audioPlayer:
        return 'AUDIO';
      default:
        return control.name.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final entry in coreEntries)
        if (!excluded.contains(entry.control)) entry,
      for (final control in DashboardVisibility.toggleable)
        if (visibleExtras.contains(control) && !excluded.contains(control))
          _DashboardEntry(labelFor(control), control),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final entry in entries)
          DashboardControl(
            key: ValueKey('dashboard-${entry.control.name}'),
            label: entry.label,
            control: entry.control,
            input: input,
            mode: _modeFor(entry.control),
            gate: gate,
            enabled: !DashboardSendGate.isUnbound(bindingFor(entry.control)),
            onBindRequested: onBindRequested,
          ),
      ],
    );
  }

  ControlMode _modeFor(ControlId control) {
    if (control == ControlId.engineStart &&
        engineStartMode == EngineStartMode.singlePress) {
      return ControlMode.momentary;
    }
    return DashboardControl.modeFor(control);
  }
}

class _DashboardEntry {
  const _DashboardEntry(this.label, this.control);
  final String label;
  final ControlId control;
}

/// A single dashboard control button.
///
/// Emits [ActionType.toggle] on tap, [ActionType.press]/[ActionType.release] on
/// momentary press, or [ActionType.holdConfirm] after a held press. When
/// [enabled] is false the button renders disabled with a "—" badge and taps
/// call [onBindRequested] instead of sending — except hole cells, which pass
/// a null [control] and no binder callback, so they are fully inert.
/// Turn-signal cells render the straight-arrow icon and blink from the gate's
/// phase; without a gate they stay visually inert.
class DashboardControl extends StatefulWidget {
  const DashboardControl({
    super.key,
    required this.label,
    required this.control,
    required this.input,
    required this.mode,
    this.holdDuration = const Duration(milliseconds: 500),
    this.onHoldCompleted,
    this.enabled = true,
    this.gate,
    this.width = DashboardControl.defaultSize,
    this.height = DashboardControl.defaultSize,
    this.onBindRequested,
  });

  /// Interaction mode for a control: toggle-pulse, momentary
  /// press/release, or hold-to-confirm. Single source of truth for how each
  /// control behaves; the dashboard grid build is driven by it.
  static ControlMode modeFor(ControlId control) {
    switch (control) {
      case ControlId.turnSignalLeft:
      case ControlId.turnSignalRight:
      case ControlId.headlightToggle:
      case ControlId.highBeamToggle:
      case ControlId.cruiseToggle:
      case ControlId.hazardLights:
      case ControlId.beaconLights:
      case ControlId.trailer:
      case ControlId.liftDropAxle:
      case ControlId.engineBrake:
      case ControlId.differentialLock:
        return ControlMode.toggle;
      case ControlId.engineStart:
        return ControlMode.holdConfirm;
      default:
        return ControlMode.momentary;
    }
  }

  final String label;

  /// The control this cell sends. Null for layout holes: the cell renders
  /// disabled and never activates anything.
  final ControlId? control;
  final DashboardInput input;
  final ControlMode mode;
  final Duration holdDuration;

  /// Called when a tap-or-hold press is held for [holdDuration]; the press
  /// itself is suppressed. Null where the hold has no meaning.
  final VoidCallback? onHoldCompleted;
  final bool enabled;
  final DashboardSendGate? gate;
  final ValueChanged<ControlId>? onBindRequested;

  /// Sides of the rectangular cell box. Grid renderers size cells from
  /// their layout slot, so the box follows the screen-derived cell aspect;
  /// the compact square default (REQ-005) is [defaultSize].
  final double width;
  final double height;
  static const double defaultSize = 64;

  @override
  State<DashboardControl> createState() => _DashboardControlState();
}

enum ControlMode { toggle, momentary, holdConfirm, tapOrHold }

class _DashboardControlState extends State<DashboardControl>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _toggled = false;
  bool _holdFired = false;
  Timer? _holdTimer;
  AnimationController? _holdProgress;

  /// Controls whose visuals read the gate: signal blink, hazard blink, and
  /// the headlight cycle.
  static bool _isGateDriven(ControlId? control) =>
      control == ControlId.hazardLights ||
      control == ControlId.headlightToggle ||
      control == ControlId.turnSignalLeft ||
      control == ControlId.turnSignalRight;

  /// Gate-driven visuals apply to the signals' blink, hazard blink, and the
  /// headlight cycle.
  bool get _gateDriven => widget.gate != null && _isGateDriven(widget.control);

  /// Active when held down (momentary/hold), switched on (toggle), or lit by
  /// the phone-held blink/cycle state. Signal visuals derive from the gate
  /// alone: inert without one.
  bool get _active {
    final gate = widget.gate;
    final control = widget.control;
    if (control != null &&
        (control == ControlId.turnSignalLeft ||
            control == ControlId.turnSignalRight)) {
      return gate?.signalVisualActive(control) ?? false;
    }
    if (gate != null && control == ControlId.hazardLights) {
      return gate.signalVisualActive(ControlId.hazardLights);
    }
    return _pressed || _toggled;
  }

  String get _label {
    final gate = widget.gate;
    if (gate != null && widget.control == ControlId.headlightToggle) {
      return switch (gate.lightStage) {
        LightStage.off => 'OFF',
        LightStage.parking => 'PARK',
        LightStage.low => 'LOW',
      };
    }
    return widget.label;
  }

  @override
  void initState() {
    super.initState();
    if (_gateDriven) widget.gate!.addListener(_onGate);
  }

  @override
  void didUpdateWidget(covariant DashboardControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate != widget.gate) {
      if (_listened(oldWidget)) oldWidget.gate!.removeListener(_onGate);
      if (_gateDriven) widget.gate!.addListener(_onGate);
    }
  }

  bool _listened(DashboardControl w) =>
      w.gate != null && _isGateDriven(w.control);

  void _onGate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdProgress?.dispose();
    if (_gateDriven) widget.gate!.removeListener(_onGate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPressable = widget.enabled && widget.mode != ControlMode.toggle;
    final icon = DashboardPanel.iconFor(widget.control);

    return GestureDetector(
      onTap: !widget.enabled
          ? () {
              final control = widget.control;
              if (control != null) widget.onBindRequested?.call(control);
            }
          : widget.mode == ControlMode.toggle
          ? _toggle
          : null,
      onTapDown: isPressable ? (_) => _pressDown() : null,
      onTapUp: isPressable ? (_) => _pressUp() : null,
      onTapCancel: isPressable ? _pressCancel : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: !widget.enabled
                  ? const Color(0xFF37474F)
                  : _active
                  ? const Color(0xFFFFB300)
                  : const Color(0xFF455A64),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _active && widget.enabled
                    ? const Color(0xFFFFE082)
                    : const Color(0xFF90A4AE),
                width: _active && widget.enabled ? 3 : 2,
              ),
              boxShadow: _active && widget.enabled
                  ? const [
                      BoxShadow(
                        color: Color(0xFFFFB300),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    size: 28,
                    color: _active && widget.enabled
                        ? Colors.black
                        : Colors.white,
                  )
                : Text(
                    _label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _active && widget.enabled
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
          ),
          if (!widget.enabled)
            const Positioned(
              right: 2,
              top: 2,
              child: Text(
                '—',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          if (widget.mode == ControlMode.tapOrHold &&
              _pressed &&
              _holdProgress != null)
            Positioned(
              left: 6,
              right: 6,
              bottom: 4,
              child: AnimatedBuilder(
                animation: _holdProgress!,
                builder: (_, _) => LinearProgressIndicator(
                  value: _holdProgress!.value,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggle() {
    final control = widget.control;
    if (control == null) return;
    setState(() => _toggled = !_toggled);
    widget.input.activate(control, ActionType.toggle);
  }

  void _pressDown() {
    if (widget.mode == ControlMode.tapOrHold) {
      // The center camera-pad cell: hold to switch mode. A null control
      // (arrow-mode center) still holds, but an early release sends
      // nothing.
      setState(() {
        _pressed = true;
        _holdFired = false;
      });
      final controller = _holdProgress ??= AnimationController(
        vsync: this,
        duration: widget.holdDuration,
      )..addStatusListener(_onHoldProgress);
      controller.duration = widget.holdDuration;
      controller.forward(from: 0);
      return;
    }

    final control = widget.control;
    if (control == null) return;
    setState(() => _pressed = true);

    if (widget.mode == ControlMode.holdConfirm) {
      _holdTimer = Timer(widget.holdDuration, () {
        if (mounted && _pressed) {
          widget.input.activate(control, ActionType.holdConfirm);
        }
      });
    } else {
      widget.input.activate(control, ActionType.press);
    }
  }

  /// Fires the hold when the progress controller completes; the press
  /// action is suppressed.
  void _onHoldProgress(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_pressed || _holdFired) return;
    _holdFired = true;
    HapticFeedback.mediumImpact();
    widget.onHoldCompleted?.call();
  }

  /// The gesture left the cell (or the widget is going away): a tap-or-hold
  /// press is cancelled outright — no press action, no hold.
  void _pressCancel() {
    if (widget.mode == ControlMode.tapOrHold) {
      _resetHold();
      if (_pressed) {
        setState(() {
          _pressed = false;
          _holdFired = false;
        });
      }
      return;
    }
    _pressUp();
  }

  /// Stops the hold animation and clears the progress bar.
  void _resetHold() {
    _holdProgress?.stop();
    _holdProgress?.reset();
  }

  void _pressUp() {
    _holdTimer?.cancel();
    _holdTimer = null;

    if (!_pressed) {
      return;
    }

    setState(() => _pressed = false);

    if (widget.mode == ControlMode.tapOrHold) {
      _resetHold();
      if (!_holdFired) {
        // A short tap: a complete press-and-release, so the game never
        // sees a stuck key.
        final control = widget.control;
        if (control != null) {
          widget.input.activate(control, ActionType.press);
          widget.input.activate(control, ActionType.release);
        }
      }
      return;
    }

    if (widget.mode == ControlMode.momentary) {
      final control = widget.control;
      if (control != null) widget.input.activate(control, ActionType.release);
    }
  }
}
