import 'package:flutter/material.dart';

import '../../input/pedal_input.dart';

/// Three vertical draggable pedal bars: accelerator, brake, and clutch.
///
/// Each bar maps touch position to analog pressure (0.0 at the top, 1.0 at the
/// bottom) and drives [PedalInput] while dragging, releasing to spring back on
/// drag end.
class PedalPanel extends StatelessWidget {
  const PedalPanel({super.key, required this.input});

  final PedalInput input;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        PedalBar(
          key: const ValueKey('pedal-accelerator'),
          pedal: PedalType.accelerator,
          label: 'ACC',
          pressure: input.pressureOf(PedalType.accelerator),
          onDrag: input.setPressure,
          onRelease: input.release,
        ),
        PedalBar(
          key: const ValueKey('pedal-brake'),
          pedal: PedalType.brake,
          label: 'BRK',
          pressure: input.pressureOf(PedalType.brake),
          onDrag: input.setPressure,
          onRelease: input.release,
        ),
        PedalBar(
          key: const ValueKey('pedal-clutch'),
          pedal: PedalType.clutch,
          label: 'CLT',
          pressure: input.pressureOf(PedalType.clutch),
          onDrag: input.setPressure,
          onRelease: input.release,
        ),
      ],
    );
  }
}

/// A single vertical pedal bar. The filled portion grows downward from the top
/// as [pressure] increases.
class PedalBar extends StatefulWidget {
  const PedalBar({
    super.key,
    required this.pedal,
    required this.label,
    required this.pressure,
    required this.onDrag,
    required this.onRelease,
  });

  final PedalType pedal;
  final String label;
  final double pressure;
  final void Function(PedalType pedal, double pressure) onDrag;
  final void Function(PedalType pedal) onRelease;

  @override
  State<PedalBar> createState() => _PedalBarState();
}

class _PedalBarState extends State<PedalBar> {
  double _dragPressure = 0.0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final pressure = _dragging ? _dragPressure : widget.pressure;

    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;

                return GestureDetector(
                  onVerticalDragStart: (details) =>
                      _setFromPosition(details.localPosition, height),
                  onVerticalDragUpdate: (details) =>
                      _setFromPosition(details.localPosition, height),
                  onVerticalDragEnd: (_) {
                    setState(() => _dragging = false);
                    widget.onRelease(widget.pedal);
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: pressure.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setFromPosition(Offset localPosition, double height) {
    final localY = localPosition.dy;
    final pressure = (localY / height).clamp(0.0, 1.0).toDouble();
    setState(() {
      _dragging = true;
      _dragPressure = pressure;
    });
    widget.onDrag(widget.pedal, pressure);
  }
}
