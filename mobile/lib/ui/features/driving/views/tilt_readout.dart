import 'package:flutter/material.dart';

/// X-axis tilt readout: a track with a marker positioned by the normalized
/// steering angle (-1.0..1.0). Shown in gyro mode (under the wheel when the
/// dashboard is hidden, top-center only when shown).
class TiltReadout extends StatelessWidget {
  const TiltReadout({super.key, required this.angle});

  /// Normalized steering angle.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tilt-readout'),
      width: 160,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF37474F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90A4AE), width: 2),
      ),
      child: Stack(
        children: [
          const Center(
            child: SizedBox(
              width: 2,
              height: 12,
              child: ColoredBox(color: Colors.white30),
            ),
          ),
          Align(
            key: const ValueKey('tilt-marker'),
            alignment: Alignment(angle.clamp(-1.0, 1.0).toDouble(), 0),
            child: const SizedBox(
              width: 12,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFB300),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
