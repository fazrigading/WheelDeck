import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import '../../../../data/services/dashboard_visibility.dart';
import '../../../../data/services/engine_start_mode.dart';

/// The truck-styled dashboard control grid.
///
/// Renders the always-shown [coreControls] plus the visible
/// [DashboardVisibility.toggleable] extras, and forwards activation events to
/// [DashboardInput]. Turn signals never appear here: [SignalArrows] owns them.
/// Unbound controls (empty per-mode binding) render disabled with a "—" badge;
/// tapping one calls [onBindRequested] instead of sending.
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
  /// design; [SignalArrows] is their single source of truth.
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
  static const coreControls = [    ControlId.headlightToggle,
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
            enabled:
                !DashboardSendGate.isUnbound(bindingFor(entry.control)),
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

/// A single dashboard control button (64px).
///
/// Emits [ActionType.toggle] on tap, [ActionType.press]/[ActionType.release] on
/// momentary press, or [ActionType.holdConfirm] after a held press. When
/// [enabled] is false the button renders disabled with a "—" badge and taps
/// call [onBindRequested] instead of sending.
class DashboardControl extends StatefulWidget {
  const DashboardControl({
    super.key,
    required this.label,
    required this.control,
    required this.input,
    required this.mode,
    this.holdDuration = const Duration(milliseconds: 500),
    this.enabled = true,
    this.gate,
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
  final ControlId control;
  final DashboardInput input;
  final ControlMode mode;
  final Duration holdDuration;
  final bool enabled;
  final DashboardSendGate? gate;
  final ValueChanged<ControlId>? onBindRequested;

  /// Compact 64px control size (REQ-005).
  static const double size = 64;

  @override
  State<DashboardControl> createState() => _DashboardControlState();
}

enum ControlMode { toggle, momentary, holdConfirm }

class _DashboardControlState extends State<DashboardControl> {
  bool _pressed = false;
  bool _toggled = false;
  Timer? _holdTimer;

  /// Gate-driven visuals apply to hazard (blink) and the headlight cycle.
  bool get _gateDriven =>
      widget.gate != null &&
      (widget.control == ControlId.hazardLights ||
          widget.control == ControlId.headlightToggle);

  /// Active when held down (momentary/hold), switched on (toggle), or lit by
  /// the phone-held blink/cycle state.
  bool get _active {
    final gate = widget.gate;
    if (gate != null && widget.control == ControlId.hazardLights) {
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
      w.gate != null &&
      (w.control == ControlId.hazardLights ||
          w.control == ControlId.headlightToggle);

  void _onGate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    if (_gateDriven) widget.gate!.removeListener(_onGate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rounded-rectangle fallback on small phones (REQ-005).
    final compact = MediaQuery.sizeOf(context).width < 380;
    final isPressable = widget.enabled && widget.mode != ControlMode.toggle;

    return GestureDetector(
      onTap: !widget.enabled
          ? () => widget.onBindRequested?.call(widget.control)
          : widget.mode == ControlMode.toggle
              ? _toggle
              : null,
      onTapDown: isPressable ? (_) => _pressDown() : null,
      onTapUp: isPressable ? (_) => _pressUp() : null,
      onTapCancel: isPressable ? _pressUp : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: DashboardControl.size,
            height: DashboardControl.size,
            decoration: BoxDecoration(
              color: !widget.enabled
                  ? const Color(0xFF37474F)
                  : _active
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF455A64),
              shape: compact ? BoxShape.rectangle : BoxShape.circle,
              borderRadius:
                  compact ? BorderRadius.circular(16) : null,
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
            child: Text(
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
              child: Text('—',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ),
        ],
      ),
    );
  }

  void _toggle() {
    setState(() => _toggled = !_toggled);
    widget.input.activate(widget.control, ActionType.toggle);
  }

  void _pressDown() {
    setState(() => _pressed = true);

    if (widget.mode == ControlMode.holdConfirm) {
      _holdTimer = Timer(widget.holdDuration, () {
        if (mounted && _pressed) {
          widget.input.activate(widget.control, ActionType.holdConfirm);
        }
      });
    } else {
      widget.input.activate(widget.control, ActionType.press);
    }
  }

  void _pressUp() {
    _holdTimer?.cancel();
    _holdTimer = null;

    if (!_pressed) {
      return;
    }

    setState(() => _pressed = false);

    if (widget.mode == ControlMode.momentary) {
      widget.input.activate(widget.control, ActionType.release);
    }
  }
}
