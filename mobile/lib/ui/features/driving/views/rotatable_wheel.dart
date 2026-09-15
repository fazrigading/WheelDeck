import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/services/rotation_mapper.dart';
import 'wheel_view.dart';

/// Finger-drag circular steering wheel for rotatable mode.
///
/// Dragging around the center accumulates clockwise-positive rotation;
/// [degrees] of finger rotation (the selected lock-to-lock range) maps to
/// full steering via [mapRotationToSteering]. Release springs back to center
/// and reports 0.0. The graphic rotates 1:1 with the finger, with a progress
/// arc over the top half of the ring plus a degree readout.
class RotatableWheel extends StatefulWidget {
  const RotatableWheel({
    super.key,
    required this.degrees,
    required this.onChanged,
    this.size = 280,
  });

  /// Selected lock-to-lock range in degrees.
  final int degrees;

  /// Called with normalized steering (-1.0..1.0) on every update and on
  /// release (always 0.0).
  final ValueChanged<double> onChanged;

  /// Diameter of the wheel graphic.
  final double size;

  @override
  State<RotatableWheel> createState() => _RotatableWheelState();
}

class _RotatableWheelState extends State<RotatableWheel> {
  double _accumulated = 0;
  double? _lastTouchAngle;

  double get _steering =>
      mapRotationToSteering(_accumulated, widget.degrees);

  double _touchAngle(Offset localPosition, Size size) {
    final center = size.center(Offset.zero);
    return math.atan2(
          -(localPosition.dy - center.dy),
          localPosition.dx - center.dx,
        ) *
        180 /
        math.pi;
  }

  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox;
    _lastTouchAngle =
        _touchAngle(box.globalToLocal(details.globalPosition), box.size);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final last = _lastTouchAngle;
    if (last == null) return;
    final box = context.findRenderObject() as RenderBox;
    final now =
        _touchAngle(box.globalToLocal(details.globalPosition), box.size);
    // Clockwise motion decreases the math-convention angle, so negate to keep
    // accumulated rotation (and steering) clockwise-positive. Clamped to
    // half-range: anything beyond is full lock, with no dead unwind.
    final halfRange = widget.degrees / 2;
    _accumulated = (_accumulated - circularDelta(last, now))
        .clamp(-halfRange, halfRange)
        .toDouble();
    _lastTouchAngle = now;
    widget.onChanged(_steering);
    setState(() {});
  }

  void _onPanEnd() {
    _accumulated = 0;
    _lastTouchAngle = null;
    widget.onChanged(0.0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) => _onPanEnd(),
        onPanCancel: _onPanEnd,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedRotation(
              turns: _accumulated / 360,
              duration: const Duration(milliseconds: 80),
              child: WheelGraphic(size: widget.size),
            ),
            CustomPaint(
              painter: _RotationArcPainter(
                progress: (_steering + 1) / 2,
              ),
              size: Size.square(widget.size),
            ),
            Positioned(
              bottom: 0,
              child: Text(
                '${_accumulated.round()}°',
                key: const ValueKey('rotation-readout'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress arc over the top half of the ring, tracking steering.
class _RotationArcPainter extends CustomPainter {
  const _RotationArcPainter({required this.progress});

  /// 0.0 (full left) to 1.0 (full right).
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, track);

    final fill = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi * progress.clamp(0.0, 1.0), false, fill);
  }

  @override
  bool shouldRepaint(covariant _RotationArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
