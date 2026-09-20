import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/services/rotation_mapper.dart';
import 'wheel_view.dart';

/// Finger-drag circular steering wheel for rotatable mode.
///
/// Dragging around the center accumulates clockwise-positive rotation;
/// [degrees] of finger rotation (the selected lock-to-lock range) maps to
/// full steering via [mapRotationToSteering]. When [springBack] is on,
/// release animates back to center over [springBackDuration] with an eased
/// curve and reports 0.0 on completion; when off, the wheel holds its
/// released angle and steering stays there until dragged back. The graphic
/// rotates 1:1 with the finger, with a progress arc over the top half of the
/// ring plus a degree readout.
class RotatableWheel extends StatefulWidget {
  const RotatableWheel({
    super.key,
    required this.degrees,
    required this.onChanged,
    this.size = 280,
    this.springBack = true,
    this.springBackDuration = const Duration(milliseconds: 700),
  });

  /// Selected lock-to-lock range in degrees.
  final int degrees;

  /// Called with normalized steering (-1.0..1.0) on every update, on release
  /// (the held angle when spring-back is off), and on spring-back completion
  /// (always 0.0).
  final ValueChanged<double> onChanged;

  /// Diameter of the wheel graphic.
  final double size;

  /// Whether release animates the wheel back to zero. Off holds the
  /// released angle until the driver drags it back.
  final bool springBack;

  /// How long the eased spring-back to zero runs.
  final Duration springBackDuration;

  @override
  State<RotatableWheel> createState() => _RotatableWheelState();
}

class _RotatableWheelState extends State<RotatableWheel>
    with TickerProviderStateMixin {
  double _accumulated = 0;
  double? _lastTouchAngle;
  AnimationController? _springBack;
  double _springStart = 0;

  double get _steering => mapRotationToSteering(_accumulated, widget.degrees);

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
    // A new drag takes over from wherever the spring-back currently is.
    _springBack?.stop();
    _teardownSpringBack();
    final box = context.findRenderObject() as RenderBox;
    _lastTouchAngle = _touchAngle(
      box.globalToLocal(details.globalPosition),
      box.size,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final last = _lastTouchAngle;
    if (last == null) return;
    final box = context.findRenderObject() as RenderBox;
    final now = _touchAngle(
      box.globalToLocal(details.globalPosition),
      box.size,
    );
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
    _lastTouchAngle = null;
    if (!widget.springBack) {
      // Hold the released angle; steering stays until dragged back.
      widget.onChanged(_steering);
      return;
    }
    if (_accumulated == 0) {
      widget.onChanged(0.0);
      return;
    }

    final controller = AnimationController(
      vsync: this,
      duration: widget.springBackDuration,
    );
    _springStart = _accumulated;
    controller
      ..addListener(() {
        setState(() {
          _accumulated =
              _springStart *
              (1 - Curves.easeOutCubic.transform(controller.value));
        });
        // Report per tick, so the desktop's steering tracks the visual
        // instead of freezing at the released angle until completion.
        widget.onChanged(_steering);
      })
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _teardownSpringBack();
        _accumulated = 0;
        widget.onChanged(0.0);
        setState(() {});
      });
    _springBack = controller;
    controller.forward();
  }

  void _teardownSpringBack() {
    _springBack?.dispose();
    _springBack = null;
  }

  @override
  void dispose() {
    _teardownSpringBack();
    super.dispose();
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
            // Rotation is 1:1 with the finger while dragging; the spring-back
            // controller drives the same field per tick when releasing, so
            // the visual and the reported steering stay coherent.
            Transform.rotate(
              angle: _accumulated * math.pi / 180,
              child: WheelGraphic(size: widget.size),
            ),
            CustomPaint(
              painter: RotationArcPainter(steering: _steering),
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
///
/// The track is the 180-degree arc across the top. The fill starts at twelve
/// o'clock and grows toward the turned side, proportional to the steering
/// magnitude; zero steering fills nothing.
class RotationArcPainter extends CustomPainter {
  const RotationArcPainter({required this.steering});

  /// Normalized steering (-1.0..1.0); negative is left, positive right.
  final double steering;

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

    if (steering == 0) return;
    // Twelve o'clock is 3*pi/2 in Flutter's y-down convention; positive
    // steering sweeps clockwise into the right half.
    final fill = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      math.pi * 3 / 2,
      (math.pi / 2) * steering,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant RotationArcPainter oldDelegate) =>
      oldDelegate.steering != steering;
}
