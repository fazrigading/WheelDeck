import 'package:flutter/material.dart';

import '../../../../data/services/pedal_input.dart';

/// Returns the pedal's hue: blue accelerator, red brake, yellow clutch.
Color _hue(PedalType pedal) => switch (pedal) {
  PedalType.accelerator => const Color(0xFF1E88E5),
  PedalType.brake => const Color(0xFFE53935),
  PedalType.clutch => const Color(0xFFFDD835),
};

/// Three vertical draggable pedal bars: accelerator, brake, and clutch.
///
/// Each bar maps touch position to analog pressure (0.0 at the top, 1.0 at the
/// bottom) and drives [PedalInput] while dragging, releasing to spring back on
/// drag end. Bars are hue-coded instead of labeled.
class PedalPanel extends StatelessWidget {
  const PedalPanel({super.key, required this.input, this.layout});

  final PedalInput input;
  final List<PedalType>? layout;

  @override
  Widget build(BuildContext context) {
    final order =
        layout ??
        const [PedalType.clutch, PedalType.brake, PedalType.accelerator];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: order.map((pedal) {
        final keyName = switch (pedal) {
          PedalType.clutch => 'pedal-clutch',
          PedalType.brake => 'pedal-brake',
          PedalType.accelerator => 'pedal-accelerator',
        };
        return PedalBar(
          key: ValueKey(keyName),
          pedal: pedal,
          pressure: input.pressureOf(pedal),
          onDrag: input.setPressure,
          onRelease: input.release,
        );
      }).toList(),
    );
  }
}

/// A single vertical pedal bar. The filled portion grows downward from the top
/// as [pressure] increases.
class PedalBar extends StatefulWidget {
  const PedalBar({
    super.key,
    required this.pedal,
    required this.pressure,
    required this.onDrag,
    required this.onRelease,
    this.width = 64,
  });

  final PedalType pedal;
  final double pressure;
  final void Function(PedalType pedal, double pressure) onDrag;
  final void Function(PedalType pedal) onRelease;

  /// Bar width. Null lets the bar fill the width its parent gives it, which
  /// is how slot-sized grid renderers place it.
  final double? width;

  @override
  State<PedalBar> createState() => _PedalBarState();
}

class _PedalBarState extends State<PedalBar> {
  double _dragPressure = 0.0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final pressure = _dragging ? _dragPressure : widget.pressure;
    final hue = _hue(widget.pedal);

    final Widget bar = Column(
      children: [
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
                    // Dark base with the pedal's hue tinted at 25% on top.
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: hue.withValues(alpha: 0.25),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: pressure.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: hue,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
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
    );

    final width = widget.width;
    return width == null ? bar : SizedBox(width: width, child: bar);
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
