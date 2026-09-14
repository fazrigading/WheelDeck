import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/services/dashboard_input.dart';

/// The truck-styled dashboard control panel.
///
/// Renders every [ControlId] as a toggle, momentary, or hold-to-confirm control
/// and forwards activation events to [DashboardInput].
class DashboardPanel extends StatelessWidget {
  const DashboardPanel({super.key, required this.input});

  final DashboardInput input;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (final entry in _entries)
          DashboardControl(
            key: ValueKey('dashboard-${entry.control.name}'),
            label: entry.label,
            control: entry.control,
            input: input,
            mode: DashboardControl.modeFor(entry.control),
          ),
      ],
    );
  }

  static const _entries = [
    _DashboardEntry('L', ControlId.turnSignalLeft),
    _DashboardEntry('R', ControlId.turnSignalRight),
    _DashboardEntry('LIGHT', ControlId.headlightToggle),
    _DashboardEntry('HI', ControlId.highBeamToggle),
    _DashboardEntry('CRUISE', ControlId.cruiseToggle),
    _DashboardEntry('SET', ControlId.cruiseSetResume),
    _DashboardEntry('PARK', ControlId.parkingBrake),
    _DashboardEntry('WIPE', ControlId.wipers),
    _DashboardEntry('START', ControlId.engineStart),
  ];
}

class _DashboardEntry {
  const _DashboardEntry(this.label, this.control);
  final String label;
  final ControlId control;
}

/// A single dashboard control button.
///
/// Emits [ActionType.toggle] on tap, [ActionType.press]/[ActionType.release] on
/// momentary press, or [ActionType.holdConfirm] after a held press.
class DashboardControl extends StatefulWidget {
  const DashboardControl({
    super.key,
    required this.label,
    required this.control,
    required this.input,
    required this.mode,
    this.holdDuration = const Duration(milliseconds: 500),
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

  @override
  State<DashboardControl> createState() => _DashboardControlState();
}

enum ControlMode { toggle, momentary, holdConfirm }

class _DashboardControlState extends State<DashboardControl> {
  bool _pressed = false;
  bool _toggled = false;
  Timer? _holdTimer;

  /// Active when held down (momentary/hold) or switched on (toggle).
  bool get _active => _pressed || _toggled;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPressable = widget.mode != ControlMode.toggle;

    return GestureDetector(
      onTap: widget.mode == ControlMode.toggle ? _toggle : null,
      onTapDown: isPressable ? (_) => _pressDown() : null,
      onTapUp: isPressable ? (_) => _pressUp() : null,
      onTapCancel: isPressable ? _pressUp : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: _active ? const Color(0xFFFFB300) : const Color(0xFF455A64),
          shape: BoxShape.circle,
          border: Border.all(
            color: _active
                ? const Color(0xFFFFE082)
                : const Color(0xFF90A4AE),
            width: _active ? 3 : 2,
          ),
          boxShadow: _active
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
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: _active ? Colors.black : Colors.white,
          ),
        ),
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
