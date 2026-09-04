import 'dart:async';

import 'package:flutter/material.dart';

import '../../input/dashboard_input.dart';

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
        DashboardControl.toggle(
          key: const ValueKey('dashboard-turnSignalLeft'),
          label: 'L',
          control: ControlId.turnSignalLeft,
          input: input,
        ),
        DashboardControl.toggle(
          key: const ValueKey('dashboard-turnSignalRight'),
          label: 'R',
          control: ControlId.turnSignalRight,
          input: input,
        ),
        DashboardControl.toggle(
          key: const ValueKey('dashboard-headlightToggle'),
          label: 'LIGHT',
          control: ControlId.headlightToggle,
          input: input,
        ),
        DashboardControl.toggle(
          key: const ValueKey('dashboard-highBeamToggle'),
          label: 'HI',
          control: ControlId.highBeamToggle,
          input: input,
        ),
        DashboardControl.toggle(
          key: const ValueKey('dashboard-cruiseToggle'),
          label: 'CRUISE',
          control: ControlId.cruiseToggle,
          input: input,
        ),
        DashboardControl.momentary(
          key: const ValueKey('dashboard-cruiseSetResume'),
          label: 'SET',
          control: ControlId.cruiseSetResume,
          input: input,
        ),
        DashboardControl.momentary(
          key: const ValueKey('dashboard-parkingBrake'),
          label: 'PARK',
          control: ControlId.parkingBrake,
          input: input,
        ),
        DashboardControl.momentary(
          key: const ValueKey('dashboard-wipers'),
          label: 'WIPE',
          control: ControlId.wipers,
          input: input,
        ),
        DashboardControl.holdConfirm(
          key: const ValueKey('dashboard-engineStart'),
          label: 'START',
          control: ControlId.engineStart,
          input: input,
        ),
      ],
    );
  }
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

  const DashboardControl.toggle({
    Key? key,
    required String label,
    required ControlId control,
    required DashboardInput input,
  })  : this(key: key, label: label, control: control, input: input, mode: ControlMode.toggle);

  const DashboardControl.momentary({
    Key? key,
    required String label,
    required ControlId control,
    required DashboardInput input,
  })  : this(key: key, label: label, control: control, input: input, mode: ControlMode.momentary);

  const DashboardControl.holdConfirm({
    Key? key,
    required String label,
    required ControlId control,
    required DashboardInput input,
  })  : this(key: key, label: label, control: control, input: input, mode: ControlMode.holdConfirm);

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
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPressable = widget.mode != ControlMode.toggle;

    return GestureDetector(
      onTap: widget.mode == ControlMode.toggle
          ? () => widget.input.activate(widget.control, ActionType.toggle)
          : null,
      onTapDown: isPressable ? (_) => _pressDown() : null,
      onTapUp: isPressable ? (_) => _pressUp() : null,
      onTapCancel: isPressable ? _pressUp : null,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFF4A2A2A) : const Color(0xFF2A2A2A),
          shape: BoxShape.circle,
          border: Border.all(
            color: _pressed
                ? const Color(0xFFE53935)
                : const Color(0xFF6A6A6A),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
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
