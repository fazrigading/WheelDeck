import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The on-screen steering wheel.
///
/// Rotates in response to the normalized steering angle (-1.0..1.0) produced by
/// [SteeringSensor.onAngleChanged]. A full-lock angle maps to [maxWheelRotation]
/// radians of visible rotation, so the graphic stays readable while still
/// tracking input.
class WheelView extends StatelessWidget {
  const WheelView({
    super.key,
    required this.angle,
    this.maxWheelRotation = math.pi / 2,
  });

  /// Normalized steering angle, -1.0 (full left) to 1.0 (full right).
  final double angle;

  /// Visible wheel rotation, in radians, at full lock.
  final double maxWheelRotation;

  @override
  Widget build(BuildContext context) {
    final turns = (angle.clamp(-1.0, 1.0) * maxWheelRotation) / (2 * math.pi);

    return SizedBox.square(
      dimension: 280,
      child: AnimatedRotation(
        turns: turns,
        duration: const Duration(milliseconds: 80),
        child: const _WheelGraphic(),
      ),
    );
  }
}

class _WheelGraphic extends StatelessWidget {
  const _WheelGraphic();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WheelPainter(),
      size: const Size.square(280),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;

    final rim = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(center, radius, rim);

    final face = Paint()..color = const Color(0xFF1E1E1E);
    canvas.drawCircle(center, radius - 14, face);

    final spoke = Paint()
      ..color = const Color(0xFFB0B0B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawLine(
      center - Offset(radius - 20, 0),
      center + Offset(radius - 20, 0),
      spoke,
    );
    canvas.drawLine(
      center - Offset(0, radius - 20),
      center + Offset(0, radius - 20),
      spoke,
    );

    final topMarker = Paint()..color = const Color(0xFFE53935);
    canvas.drawCircle(
      center - Offset(0, radius - 20),
      6,
      topMarker,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
