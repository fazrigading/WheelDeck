import 'package:flutter/material.dart';

import '../../../../data/services/dashboard_input.dart';
import '../../../../data/services/dashboard_send_gate.dart';
import 'dashboard_panel.dart';

/// Turn-signal arrows with phone-held blink visuals.
///
/// Single source of truth for L/R in both steering modes; the grid never
/// shows them. Active arrows light amber on the gate's ~1.5Hz blink phase;
/// hazard drives both.
class SignalArrows extends StatelessWidget {
  const SignalArrows({super.key, required this.input, required this.gate});

  final DashboardInput input;
  final DashboardSendGate gate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          key: const ValueKey('signal-left'),
          icon: Icons.turn_left,
          control: ControlId.turnSignalLeft,
          input: input,
          gate: gate,
        ),
        const SizedBox(width: 8),
        _ArrowButton(
          key: const ValueKey('signal-right'),
          icon: Icons.turn_right,
          control: ControlId.turnSignalRight,
          input: input,
          gate: gate,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    super.key,
    required this.icon,
    required this.control,
    required this.input,
    required this.gate,
  });

  final IconData icon;
  final ControlId control;
  final DashboardInput input;
  final DashboardSendGate gate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => input.activate(control, ActionType.toggle),
      child: ListenableBuilder(
        listenable: gate,
        builder: (context, _) {
          final active = gate.signalVisualActive(control);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: DashboardControl.defaultSize,
            height: DashboardControl.defaultSize,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFB300) : const Color(0xFF455A64),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? const Color(0xFFFFE082)
                    : const Color(0xFF90A4AE),
                width: active ? 3 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}
