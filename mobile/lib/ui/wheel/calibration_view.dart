import 'package:flutter/material.dart';

import '../../input/steering_sensor.dart';

/// Calibration screen for the steering sensor.
///
/// Shows the current normalized steering angle and a button that captures the
/// phone's present orientation as "straight ahead" via [SteeringSensor.setCenter].
class CalibrationView extends StatelessWidget {
  const CalibrationView({
    super.key,
    required this.sensor,
    this.angle = 0.0,
  });

  final SteeringSensor sensor;

  /// Current normalized steering angle (-1.0..1.0), read from the sensor.
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Steering angle: ${angle.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: sensor.setCenter,
            child: const Text('Set straight ahead'),
          ),
        ],
      ),
    );
  }
}
